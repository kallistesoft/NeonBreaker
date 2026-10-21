import 'package:flutter_test/flutter_test.dart';
import 'package:neon_breaker/game/levels.dart';
import 'package:neon_breaker/game/model.dart';
import 'package:neon_breaker/game/world.dart';

/// Plays a level with a simple bot: the paddle tracks the lowest falling ball.
WorldState autoplay(GameWorld w, {double seconds = 600}) {
  const dt = 1 / 60;
  for (var t = 0.0; t < seconds; t += dt) {
    final falling = w.balls.where((b) => !b.stuck).toList()..sort((a, b) => b.pos.dy.compareTo(a.pos.dy));
    // Aim slightly off-center so the ball doesn't loop straight up and down forever.
    if (falling.isNotEmpty) w.movePaddleTo(falling.first.pos.dx + 9 * (t % 4 < 2 ? 1 : -1));
    w.launch();
    w.update(dt);
    w.events.clear();
    if (w.state == WorldState.won || w.state == WorldState.lost) break;
  }
  return w.state;
}

void main() {
  group('levels', () {
    test('a boss every 5 levels, regular levels have bricks to break', () {
      for (var n = 1; n <= 80; n++) {
        final l = buildLevel(n);
        expect(l.isBoss, n % 5 == 0, reason: 'level $n');
        if (!l.isBoss) expect(l.bricks.where((b) => b.kind != BrickKind.steel), isNotEmpty, reason: 'level $n');
      }
    });

    test('consecutive regular levels never repeat a shape', () {
      String? previous;
      for (var n = 1; n <= 200; n++) {
        final l = buildLevel(n);
        if (l.isBoss) continue;
        expect(l.name, isNot(previous), reason: 'level $n');
        previous = l.name;
      }
    });

    test('bosses rotate and get tougher', () {
      expect([5, 10, 15, 20].map((n) => buildLevel(n).boss), BossKind.values);
      expect(buildLevel(25).bossHp, greaterThan(buildLevel(5).bossHp));
      expect(buildLevel(25).bossPower, greaterThan(buildLevel(5).bossPower));
    });

    test('difficulty rises: faster ball, smaller paddle, tougher bricks', () {
      final a = buildLevel(1), b = buildLevel(24);
      expect(b.ballSpeed, greaterThan(a.ballSpeed));
      expect(b.paddleWidth, lessThan(a.paddleWidth));
      int maxHp(LevelSpec l) => l.bricks.map((b) => b.hp).reduce((x, y) => x > y ? x : y);
      expect(maxHp(b), greaterThan(maxHp(a)));
    });

    test('bricks stay inside the grid and never overlap', () {
      for (var n = 1; n <= 120; n++) {
        final l = buildLevel(n);
        final cells = <(int, int)>{};
        for (final b in l.bricks) {
          expect(b.col, inInclusiveRange(0, gridCols - 1));
          expect(gridTop + b.row * rowStep + brickH, lessThan(paddleY - 150), reason: 'level $n too low');
          expect(cells.add((b.col, b.row)), isTrue, reason: 'level $n overlap at ${b.col},${b.row}');
        }
      }
    });

    test('checkpoint is the level after the last boss', () {
      expect([1, 4, 5, 6, 10, 11, 14].map(checkpointFor), [1, 1, 1, 6, 6, 11, 11]);
    });
  });

  group('world', () {
    test('ball waits on the paddle until launch', () {
      final w = GameWorld(buildLevel(1), lives: 3, score: 0);
      w.update(0.5);
      expect(w.hasStuckBall, isTrue);
      w.launch();
      w.update(0.1);
      expect(w.hasStuckBall, isFalse);
      expect(w.balls.single.vel.dy, lessThan(0));
    });

    test('missing the ball costs a life, then the game ends', () {
      final w = GameWorld(buildLevel(1), lives: 2, score: 0);
      w.launch();
      w.balls.single
        ..pos = const Offset(10, 600)
        ..vel = const Offset(0, 300);
      w.movePaddleTo(300);
      for (var i = 0; i < 60; i++) {
        w.update(1 / 60);
      }
      expect(w.lives, 1);
      expect(w.hasStuckBall, isTrue);
      w.launch();
      w.balls.single
        ..pos = const Offset(10, 600)
        ..vel = const Offset(0, 300);
      for (var i = 0; i < 60; i++) {
        w.update(1 / 60);
      }
      expect(w.state, WorldState.lost);
    });

    test('explosive bricks take their neighbors with them', () {
      final w = GameWorld(buildLevel(4), lives: 3, score: 0);
      final bomb = w.bricks.firstWhere((b) => b.kind == BrickKind.explosive);
      final before = w.bricksLeft;
      w.balls.single
        ..stuck = false
        ..pos = bomb.rect(0, 0).bottomCenter + const Offset(0, ballRadius + 1)
        ..vel = const Offset(0, -300);
      w.update(1 / 60);
      expect(w.bricksLeft, lessThan(before - 1));
    });

    test('multi-ball splits every ball', () {
      final w = GameWorld(buildLevel(1), lives: 3, score: 0);
      w.launch();
      w.powerUps.add(PowerUp(PowerKind.multi, Offset(w.paddleX, paddleY)));
      w.update(1 / 60);
      expect(w.balls.length, 3);
    });

    test('boss shots stun the paddle', () {
      final w = GameWorld(buildLevel(5), lives: 3, score: 0);
      w.bossShots.add(Shot(Offset(w.paddleX, paddleY - 5), const Offset(0, 100)));
      w.update(1 / 60);
      expect(w.stun, greaterThan(0));
      final x = w.paddleX;
      w.movePaddleTo(20);
      w.update(1 / 60);
      expect(w.paddleX, x);
    });

    for (final n in [1, 2, 3, 4, 6, 7, 8, 9, 12, 13, 14, 17]) {
      test('level $n can be cleared', () {
        expect(autoplay(GameWorld(buildLevel(n), lives: 99, score: 0)), WorldState.won);
      });
    }

    for (final n in [5, 10, 15, 20]) {
      test('boss level $n can be beaten', () {
        final w = GameWorld(buildLevel(n), lives: 99, score: 0);
        expect(autoplay(w), WorldState.won);
        expect(w.boss!.hp, 0);
      });
    }
  });
}
