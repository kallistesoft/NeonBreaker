import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neon_breaker/game/world.dart';
import 'package:neon_breaker/main.dart';
import 'package:neon_breaker/services/ad_service.dart';
import 'package:neon_breaker/services/progress_store.dart';
import 'package:neon_breaker/services/sound_service.dart';
import 'package:neon_breaker/ui/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CountingAds implements AdService {
  int shown = 0;

  @override
  Future<void> showInterstitial() async => shown++;
}

void main() {
  late ProgressStore progress;
  late CountingAds ads;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    progress = await ProgressStore.open();
    ads = CountingAds();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412 * 3, 880 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(NeonBreakerApp(progress: progress, ads: ads, sound: NoSound()));
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
}
