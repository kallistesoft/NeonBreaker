import 'dart:math';

import 'package:flutter/material.dart';

import '../game/levels.dart';
import '../game/model.dart';
import '../game/world.dart';
import 'effects.dart';
import 'palette.dart';

/// Draws the world in its own 360×640 coordinates; the caller scales the canvas.
class WorldPainter extends CustomPainter {
  WorldPainter({required this.world, required this.effects, required this.theme, required Listenable repaint}) : super(repaint: repaint);

  final GameWorld world;
  final Effects effects;
  final LevelTheme theme;

  static final _glow = MaskFilter.blur(BlurStyle.normal, 5);
  static final _bigGlow = MaskFilter.blur(BlurStyle.normal, 12);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / worldW);
    _background(canvas);
    canvas.save();
    canvas.translate(effects.shakeOffset.dx, effects.shakeOffset.dy);
    _bricks(canvas);
    if (world.boss != null) _boss(canvas, world.boss!);
    _powerUps(canvas);
    _shots(canvas);
    _paddle(canvas);
    _balls(canvas);
    _effects(canvas);
    canvas.restore();
    _hud(canvas);
  }

  void _background(Canvas canvas) {
    const field = Rect.fromLTWH(0, 0, worldW, worldH);
    canvas.drawRect(
      field,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.top, theme.bottom],
        ).createShader(field),
    );
    // Synthwave floor: perspective lines and rows scrolling toward the player.
    const horizon = 330.0;
    final line = Paint()
      ..color = theme.grid.withValues(alpha: 0.13)
      ..strokeWidth = 1;
    for (var i = -8; i <= 8; i++) {
      canvas.drawLine(Offset(worldW / 2 + i * 12, horizon), Offset(worldW / 2 + i * 70, worldH), line);
    }
    final scroll = (world.time * 0.35) % 1;
    for (var i = 0; i < 9; i++) {
      final t = (i + scroll) / 9;
      final y = horizon + (worldH - horizon) * t * t;
      canvas.drawLine(Offset(0, y), Offset(worldW, y), line..color = theme.grid.withValues(alpha: 0.05 + 0.14 * t));
    }
    canvas.drawLine(
      const Offset(0, fieldTop),
      const Offset(worldW, fieldTop),
      Paint()
        ..color = theme.accent.withValues(alpha: 0.35)
        ..strokeWidth = 1,
    );
  }

  void _bricks(Canvas canvas) {
    final off = world.brickOffset;
    for (final b in world.bricks) {
      if (!b.alive) continue;
      final r = b.rect(off.dx, off.dy);
      final color = switch (b.kind) {
        BrickKind.steel => steelColor,
        BrickKind.explosive => explosiveColor,
        BrickKind.normal => brickColor(world.spec.number, b.row),
      };
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(3));
      final flash = b.flash > 0;
      // Tougher bricks are more solid.
      final fill = b.kind == BrickKind.normal ? 0.22 + 0.13 * (b.hp - 1) : (b.kind == BrickKind.steel ? 0.55 : 0.4);
      canvas.drawRRect(rr, Paint()..color = (flash ? Colors.white : color).withValues(alpha: min(0.8, fill)));
      canvas.drawRRect(
        rr.deflate(0.75),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = flash ? Colors.white : color,
      );
      // Top highlight.
      canvas.drawLine(
        Offset(r.left + 4, r.top + 3.5),
        Offset(r.right - 4, r.top + 3.5),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..strokeWidth = 1.2,
      );
      if (b.kind == BrickKind.explosive) {
        final c = r.center;
        final pulse = 0.5 + 0.5 * sin(world.time * 8);
        canvas.drawCircle(c, 3 + pulse, Paint()..color = neonYellow);
        canvas.drawCircle(
          c,
          6 + pulse * 2,
          Paint()
            ..color = neonYellow.withValues(alpha: 0.4)
            ..maskFilter = _glow,
        );
      } else if (b.kind == BrickKind.steel) {
        final bolt = Paint()..color = Colors.white.withValues(alpha: 0.5);
        canvas.drawCircle(Offset(r.left + 4, r.center.dy + 1), 1.2, bolt);
        canvas.drawCircle(Offset(r.right - 4, r.center.dy + 1), 1.2, bolt);
      } else {
        if (b.hp > 1) {
          // One pip per hit left.
          final pip = Paint()..color = Colors.white.withValues(alpha: 0.9);
          final start = r.center.dx - (b.hp - 1) * 2.5;
          for (var i = 0; i < b.hp; i++) {
            canvas.drawCircle(Offset(start + i * 5, r.center.dy + 2), 1.4, pip);
          }
        }
        if (b.hp == b.maxHp) continue;
        // Cracks show damage.
        final crack = Paint()
          ..color = Colors.black.withValues(alpha: 0.45)
          ..strokeWidth = 1;
        canvas.drawLine(Offset(r.left + 8, r.top + 2), Offset(r.center.dx, r.bottom - 3), crack);
        if (b.maxHp - b.hp > 1) canvas.drawLine(Offset(r.right - 6, r.top + 3), Offset(r.center.dx + 2, r.center.dy), crack);
      }
    }
  }

  void _boss(Canvas canvas, Boss b) {
    if (b.hp <= 0) return;
    final hitFlash = b.flash > 0;
    final body = hitFlash ? Colors.white : (b.enraged ? danger : neonPink);
    final r = b.rect;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = body;
    final fill = Paint()..color = body.withValues(alpha: 0.22);
    final glow = Paint()
      ..color = body.withValues(alpha: 0.55)
      ..maskFilter = _bigGlow;

    Path shape;
    switch (b.kind) {
      case BossKind.sentinel:
        shape = Path()
          ..moveTo(r.left, r.center.dy)
          ..lineTo(r.left + 18, r.top)
          ..lineTo(r.right - 18, r.top)
          ..lineTo(r.right, r.center.dy)
          ..lineTo(r.right - 18, r.bottom)
          ..lineTo(r.left + 18, r.bottom)
          ..close();
      case BossKind.hive:
        shape = Path()..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(14)));
      case BossKind.prism:
        shape = Path()
          ..moveTo(r.center.dx, r.top)
          ..lineTo(r.right, r.center.dy)
          ..lineTo(r.center.dx, r.bottom)
          ..lineTo(r.left, r.center.dy)
          ..close();
      case BossKind.titan:
        shape = Path()
          ..moveTo(r.left + 20, r.top)
          ..lineTo(r.right - 20, r.top)
          ..lineTo(r.right, r.bottom - 14)
          ..lineTo(r.right - 30, r.bottom)
          ..lineTo(r.left + 30, r.bottom)
          ..lineTo(r.left, r.bottom - 14)
          ..close();
    }
    canvas.drawPath(shape, glow);
    canvas.drawPath(shape, fill);
    canvas.drawPath(shape, stroke);

    // Eyes follow the paddle.
    final look = Offset((world.paddleX - r.center.dx).clamp(-40.0, 40.0) / 40 * 3, 2);
    final eye = Paint()..color = hitFlash ? body : neonYellow;
    switch (b.kind) {
      case BossKind.sentinel:
      case BossKind.prism:
        canvas.drawCircle(r.center, 9, Paint()..color = Colors.black);
        canvas.drawCircle(r.center + look, 5, eye);
      case BossKind.hive:
        final cell = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = body.withValues(alpha: 0.6);
        for (var i = -2; i <= 2; i++) {
          canvas.drawCircle(r.center + Offset(i * 16.0, -8), 6, cell);
          if (i < 2) canvas.drawCircle(r.center + Offset(i * 16.0 + 8, 6), 6, cell);
        }
        canvas.drawCircle(r.center + look, 4, eye);
      case BossKind.titan:
        for (final dx in [-30.0, 30.0]) {
          canvas.drawCircle(r.center + Offset(dx, -4), 8, Paint()..color = Colors.black);
          canvas.drawCircle(r.center + Offset(dx, -4) + look, 4.5, eye);
        }
        canvas.drawLine(r.center + const Offset(-20, 14), r.center + const Offset(20, 14), stroke..strokeWidth = 2);
    }

    for (final s in b.shields) {
      final rr = RRect.fromRectAndRadius(s, const Radius.circular(4));
      canvas.drawRRect(rr, Paint()..color = steelColor.withValues(alpha: 0.5));
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = neonCyan,
      );
    }
  }

  void _powerUps(Canvas canvas) {
    for (final p in world.powerUps) {
      final color = switch (p.kind) {
        PowerKind.life => neonPink,
        PowerKind.shrink || PowerKind.fast => danger,
        PowerKind.laser => neonYellow,
        _ => neonCyan,
      };
      final rr = RRect.fromRectAndRadius(p.rect, const Radius.circular(7));
      canvas.drawRRect(
        rr,
        Paint()
          ..color = color.withValues(alpha: 0.5)
          ..maskFilter = _glow,
      );
      canvas.drawRRect(rr, Paint()..color = color.withValues(alpha: 0.85));
      _text(canvas, p.kind.label, p.pos, 10, Colors.black);
    }
  }

  void _shots(Canvas canvas) {
    final laser = Paint()
      ..color = neonYellow
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (final s in world.lasers) {
      canvas.drawLine(s.pos, s.pos + const Offset(0, 10), laser);
    }
    for (final s in world.bossShots) {
      canvas.drawCircle(
        s.pos,
        8,
        Paint()
          ..color = danger.withValues(alpha: 0.6)
          ..maskFilter = _glow,
      );
      canvas.drawCircle(s.pos, 4.5, Paint()..color = danger);
      canvas.drawCircle(s.pos, 2, Paint()..color = Colors.white);
    }
  }

  void _paddle(Canvas canvas) {
    final r = world.paddleRect;
    final stunned = world.stun > 0;
    final flicker = stunned && (world.time * 20).floor().isEven;
    final color = stunned ? (flicker ? Colors.white : dim) : theme.accent;
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(6));
    canvas.drawRRect(
      rr.inflate(2),
      Paint()
        ..color = color.withValues(alpha: 0.6)
        ..maskFilter = _bigGlow,
    );
    canvas.drawRRect(rr, Paint()..color = color.withValues(alpha: 0.9));
    canvas.drawRRect(rr.deflate(3), Paint()..color = Colors.white.withValues(alpha: 0.5));
    if (world.effects.containsKey(PowerKind.laser)) {
      final gun = Paint()..color = neonYellow;
      canvas.drawRect(Rect.fromLTWH(r.left + 3, r.top - 5, 5, 6), gun);
      canvas.drawRect(Rect.fromLTWH(r.right - 8, r.top - 5, 5, 6), gun);
    }
  }

  void _balls(Canvas canvas) {
    for (final b in world.balls) {
      canvas.drawCircle(
        b.pos,
        ballRadius + 4,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.45)
          ..maskFilter = _glow,
      );
      canvas.drawCircle(b.pos, ballRadius, Paint()..color = Colors.white);
      // Short trail behind the ball.
      if (!b.stuck && b.vel.distance > 0) {
        final back = b.vel / b.vel.distance;
        for (var i = 1; i <= 3; i++) {
          canvas.drawCircle(
            b.pos - back * (i * 6.0),
            ballRadius - i * 1.3,
            Paint()..color = theme.accent.withValues(alpha: 0.35 - i * 0.09),
          );
        }
      }
    }
  }

  void _effects(Canvas canvas) {
    for (final p in effects.particles) {
      final a = (p.life / p.maxLife).clamp(0.0, 1.0);
      canvas.drawCircle(p.pos, p.size * (0.5 + a * 0.5), Paint()..color = p.color.withValues(alpha: a));
    }
    for (final p in effects.popups) {
      final a = (p.life / p.maxLife).clamp(0.0, 1.0);
      _text(canvas, p.text, p.pos, p.size, p.color.withValues(alpha: a), glow: true);
    }
  }

  void _hud(Canvas canvas) {
    canvas.drawRect(const Rect.fromLTWH(0, 0, worldW, fieldTop), Paint()..color = Colors.black.withValues(alpha: 0.35));
    _text(canvas, '${world.score}', const Offset(14, 22), 16, ink, align: TextAlign.left);
    _text(
      canvas,
      world.spec.isBoss ? 'BOSS ${world.spec.number}' : 'LEVEL ${world.spec.number}',
      const Offset(worldW / 2, 22),
      13,
      world.spec.isBoss ? danger : theme.accent,
      glow: true,
    );
    // Lives as small paddles, left of the pause button.
    for (var i = 0; i < world.lives; i++) {
      final r = Rect.fromLTWH(worldW - 62 - i * 16.0, 19, 12, 5);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)), Paint()..color = theme.accent);
    }
    final boss = world.boss;
    if (boss != null && boss.hp > 0) {
      const bar = Rect.fromLTWH(30, fieldTop + 8, worldW - 60, 6);
      canvas.drawRRect(RRect.fromRectAndRadius(bar, const Radius.circular(3)), Paint()..color = Colors.white.withValues(alpha: 0.12));
      final fillRect = Rect.fromLTWH(bar.left, bar.top, bar.width * boss.hp / boss.maxHp, bar.height);
      canvas.drawRRect(RRect.fromRectAndRadius(fillRect, const Radius.circular(3)), Paint()..color = boss.enraged ? danger : neonPink);
    }
  }

  void _text(Canvas canvas, String text, Offset at, double size, Color color, {bool glow = false, TextAlign align = TextAlign.center}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: size * 0.06,
          shadows: glow ? [Shadow(color: color, blurRadius: size * 0.6)] : null,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = align == TextAlign.left ? at.dx : at.dx - tp.width / 2;
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(WorldPainter old) => old.world != world || old.theme != theme;
}
