import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/share_text.dart';
import 'palette.dart';

/// What the shared image shows: a boss just beaten, or the player's best score.
class ShareCard {
  const ShareCard.boss({required String this.boss, required this.score, required this.level});

  const ShareCard.best({required this.score, required this.level}) : boss = null;

  /// 'The Titan'; null for a best-score card.
  final String? boss;
  final int score;
  final int level;

  String get text => boss != null
      ? bossShareText(boss: boss!, score: score, level: level)
      : bestScoreShareText(score: score, level: level);
}

const cardWidth = 1080.0;
const cardHeight = 1350.0; // 4:5, the tallest image feeds show uncropped

/// Draws [card] as a PNG, ready for the share sheet.
Future<Uint8List> renderShareCard(ShareCard card) async {
  final recorder = ui.PictureRecorder();
  paintShareCard(Canvas(recorder), card);
  final image = await recorder.endRecording().toImage(cardWidth.toInt(), cardHeight.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void paintShareCard(Canvas canvas, ShareCard card) {
  const w = cardWidth, h = cardHeight;
  final isBoss = card.boss != null;
  final sky = isBoss ? const [Color(0xFF120202), Color(0xFF3A0610)] : const [Color(0xFF0B0620), Color(0xFF2A0B3D)];
  final grid = isBoss ? danger : neonPink;

  canvas.drawRect(
    const Rect.fromLTWH(0, 0, w, h),
    Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(0, h), sky),
  );

  // Perspective grid on the floor.
  final line = Paint()
    ..color = grid.withValues(alpha: 0.25)
    ..strokeWidth = 2;
  const horizon = h * 0.62;
  for (var i = 0; i < 9; i++) {
    final y = horizon + (h - horizon) * (i * i) / 64;
    canvas.drawLine(Offset(0, y), Offset(w, y), line);
  }
  for (var i = -8; i <= 8; i++) {
    canvas.drawLine(Offset(w / 2 + i * 22, horizon), Offset(w / 2 + i * 190, h), line);
  }

  // A row of neon bricks, a ball and the paddle.
  const colors = [neonPink, Color(0xFFFF8A2E), neonYellow, Color(0xFF3DFF8A), neonCyan, Color(0xFF8B5CFF)];
  for (var i = 0; i < 6; i++) {
    _glowRect(canvas, RRect.fromRectAndRadius(Rect.fromLTWH(90 + i * 155.0, 70, 128, 44), const Radius.circular(10)), colors[i]);
  }
  _glowRect(canvas, RRect.fromRectAndRadius(const Rect.fromLTWH(w / 2 - 130, h - 150, 260, 30), const Radius.circular(15)), neonCyan);
  canvas.drawCircle(const Offset(w / 2 + 70, h - 230), 20, Paint()..color = Colors.white);

  var y = 190.0;
  y = _text(canvas, 'BRICK SHATTER', y, 72, neonPink);
  y = _text(canvas, 'NEON BREAKER', y + 4, 52, neonCyan);
  y += 70;
  if (isBoss) {
    y = _text(canvas, 'BOSS DEFEATED', y, 54, neonYellow);
    y = _text(canvas, card.boss!.toUpperCase(), y + 6, 112, neonPink);
  } else {
    y = _text(canvas, 'MY BEST SCORE', y, 54, neonYellow);
  }
  y = _text(canvas, formatScore(card.score), y + 30, 150, Colors.white, glow: neonCyan);
  y = _text(canvas, card.level > 1 ? 'POINTS · LEVEL ${card.level}' : 'POINTS', y, 40, dim, plain: true);
  y = _text(canvas, isBoss ? 'DID YOU?' : 'CAN YOU BEAT IT?', y + 60, 86, neonCyan);
  _text(canvas, challengeTag, y + 14, 44, ink, plain: true);
  _text(canvas, 'Free on Google Play', h - 100, 38, ink, plain: true);
}

void _glowRect(Canvas canvas, RRect r, Color color) {
  canvas.drawRRect(r, Paint()
    ..color = color.withValues(alpha: 0.7)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16));
  canvas.drawRRect(r, Paint()..color = color);
}

/// Centered single-line text with a neon glow; returns the y below it.
double _text(Canvas canvas, String text, double top, double size, Color color, {Color? glow, bool plain = false}) {
  final shadow = plain ? null : glow ?? color;
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: size * 0.06,
        color: color,
        shadows: shadow == null ? null : [Shadow(color: shadow.withValues(alpha: 0.85), blurRadius: size * 0.35)],
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: cardWidth - 80);
  painter.paint(canvas, Offset((cardWidth - painter.width) / 2, top));
  final bottom = top + painter.height;
  painter.dispose();
  return bottom;
}
