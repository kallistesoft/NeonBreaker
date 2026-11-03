import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neon_breaker/game/levels.dart';
import 'package:neon_breaker/game/world.dart';
import 'package:neon_breaker/main.dart';
import 'package:neon_breaker/services/ad_service.dart';
import 'package:neon_breaker/services/progress_store.dart';
import 'package:neon_breaker/services/rating_service.dart';
import 'package:neon_breaker/services/share_text.dart';
import 'package:neon_breaker/services/sound_service.dart';
import 'package:neon_breaker/ui/game_screen.dart';
import 'package:neon_breaker/ui/share_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CountingAds implements AdService {
  int shown = 0;
  int rewardedShown = 0;
  bool ready = false;
  bool earn = true;

  @override
  Future<void> showInterstitial() async => shown++;

  @override
  bool get rewardedReady => ready;

  @override
  Future<bool> showRewarded() async {
    rewardedShown++;
    return earn;
  }
}

class CountingRating implements RatingService {
  int prompts = 0;

  @override
  bool get available => true;
  @override
  Future<void> prompt() async => prompts++;
  @override
  Future<void> openStore() async {}
}

void main() {
  late ProgressStore progress;
  late CountingAds ads;
  late CountingRating rating;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    progress = await ProgressStore.open();
    ads = CountingAds();
    rating = CountingRating();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412 * 3, 880 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      NeonBreakerApp(
        progress: progress,
        ads: ads,
        sound: NoSound(),
        rating: rating,
        adRectangle: (_) => const SizedBox(key: Key('ad-slot'), width: 300, height: 250),
      ),
    );
  }

  GameWorld worldOf(WidgetTester tester) => (tester.state(find.byType(GameScreen)) as dynamic).world as GameWorld;

  testWidgets('clearing a level shows the ad slot, then the next level', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('play')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('pause')), findsOneWidget);
    expect(progress.savedRun!.level, 1);

    for (final b in worldOf(tester).bricks) {
      b.hp = 0;
    }
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byKey(const Key('ad-slot')), findsOneWidget);
    expect(find.text('LEVEL 1 CLEAR'), findsOneWidget);
    expect(progress.savedRun!.level, 2);

    await tester.tap(find.text('CONTINUE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(ads.shown, 1);
    expect(worldOf(tester).spec.number, 2);
    expect(find.byKey(const Key('ad-slot')), findsNothing);
  });

  testWidgets('pause and quit return home with a run to continue', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('play')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('pause')));
    await tester.pump();
    expect(find.text('PAUSED'), findsOneWidget);
    await tester.tap(find.text('QUIT'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('continue')), findsOneWidget);
  });

  Future<void> startAndLose(WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('play')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final world = worldOf(tester);
    world.lives = 1;
    world.balls.clear();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('GAME OVER'), findsOneWidget);
  }

  testWidgets('the rewarded revive continues the level once per run', (tester) async {
    ads.ready = true;
    await startAndLose(tester);
    expect(progress.savedRun, isNotNull);

    await tester.tap(find.byKey(const Key('revive')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(ads.rewardedShown, 1);
    expect(find.text('GAME OVER'), findsNothing);
    final world = worldOf(tester);
    expect(world.lives, 1);
    expect(world.hasStuckBall, isTrue);

    world.balls.clear();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('GAME OVER'), findsOneWidget);
    expect(find.byKey(const Key('revive')), findsNothing);
    expect(progress.savedRun, isNull);
  });

  testWidgets('no revive is offered without a loaded ad', (tester) async {
    await startAndLose(tester);
    expect(find.byKey(const Key('revive')), findsNothing);
    expect(progress.savedRun, isNull);
  });

  testWidgets('skipping the rewarded ad ends the run', (tester) async {
    ads.ready = true;
    ads.earn = false;
    await startAndLose(tester);
    await tester.tap(find.byKey(const Key('revive')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('GAME OVER'), findsOneWidget);
    expect(find.byKey(const Key('revive')), findsNothing);
    expect(progress.savedRun, isNull);
  });

  testWidgets('going home declines the revive', (tester) async {
    ads.ready = true;
    await startAndLose(tester);
    await tester.tap(find.text('HOME'));
    await tester.pumpAndSettle();
    expect(progress.savedRun, isNull);
    expect(find.byKey(const Key('play')), findsOneWidget);
  });

  testWidgets('retry after game over goes through the interstitial', (tester) async {
    await startAndLose(tester);
    await tester.tap(find.text('RETRY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(ads.shown, 1);
    expect(find.text('GAME OVER'), findsNothing);
  });

  testWidgets('the rating card is requested once, after the second boss', (tester) async {
    Future<void> beatBoss(int level) async {
      await progress.clearRun();
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('play')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final state = tester.state(find.byType(GameScreen)) as dynamic;
      state.world = GameWorld(buildLevel(level), lives: 3, score: 0);
      state.world.boss.hp = 0;
      for (var i = 0; i < 150; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.text('BOSS DEFEATED'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }

    await beatBoss(5);
    expect(rating.prompts, 0);
    await beatBoss(10);
    expect(rating.prompts, 1);
    await beatBoss(15);
    expect(rating.prompts, 1);
  });

  testWidgets('home offers sharing once there is a score, and rating', (tester) async {
    await pumpApp(tester);
    await tester.pump();
    expect(find.byKey(const Key('share')), findsNothing);
    expect(find.byKey(const Key('rate')), findsOneWidget);

    await progress.recordScore(18240);
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester);
    await tester.pump();
    expect(find.byKey(const Key('share')), findsOneWidget);
  });

  test('the shared text dares friends with the score, the hashtag and the store link', () {
    final text = bestScoreShareText(score: 18240, level: 12);
    expect(text, contains('18,240'));
    expect(text, contains('level 12'));
    expect(text, contains('Can you beat it?'));
    expect(text, contains('#NeonBreakerChallenge'));
    expect(text, contains('id=ca.kallistesoft.neon_breaker'));
  });

  test('the boss text names the boss and asks "did you?"', () {
    final text = ShareCard.boss(boss: 'The Titan', score: 4860, level: 20).text;
    expect(text, contains('I just beat The Titan'));
    expect(text, contains('4,860'));
    expect(text, contains('Did you?'));
    expect(text, contains('#NeonBreakerChallenge'));
    expect(text, contains('id=ca.kallistesoft.neon_breaker'));
  });

  testWidgets('the share card renders as a 1080 x 1350 PNG', (tester) async {
    final png = await tester.runAsync(() => renderShareCard(const ShareCard.boss(boss: 'The Titan', score: 4860, level: 20)));
    expect(png!.sublist(1, 4), 'PNG'.codeUnits);
    final image = await tester.runAsync(() => decodeImageFromList(png));
    expect([image!.width, image.height], [1080, 1350]);
  });

  testWidgets('beating a boss offers to challenge friends; a normal level does not', (tester) async {
    Future<void> clear(int level) async {
      await progress.clearRun();
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('play')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final state = tester.state(find.byType(GameScreen)) as dynamic;
      state.world = GameWorld(buildLevel(level), lives: 3, score: 0);
      if (state.world.boss != null) {
        state.world.boss.hp = 0;
      } else {
        for (final b in state.world.bricks) {
          b.hp = 0;
        }
      }
      for (var i = 0; i < 150; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    await clear(5);
    expect(find.text('BOSS DEFEATED'), findsOneWidget);
    expect(find.byKey(const Key('shareBoss')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());

    await clear(4);
    expect(find.text('LEVEL 4 CLEAR'), findsOneWidget);
    expect(find.byKey(const Key('shareBoss')), findsNothing);
  });
}
