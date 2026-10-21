import 'package:flutter/material.dart';

const background = Color(0xFF07060F);
const ink = Color(0xFFE8E6FF);
const dim = Color(0xFF8C88B0);
const neonCyan = Color(0xFF22E6FF);
const neonPink = Color(0xFFFF2E97);
const neonYellow = Color(0xFFFFE14D);
const danger = Color(0xFFFF3B3B);

const _neons = <Color>[Color(0xFFFF2E97), Color(0xFFFF8A2E), Color(0xFFFFE14D), Color(0xFF3DFF8A), Color(0xFF22E6FF), Color(0xFF8B5CFF)];

/// Bricks are colored by row, starting at a different hue each level; hits left show as pips.
Color brickColor(int level, int row) => _neons[(row + level * 2) % _neons.length];

const steelColor = Color(0xFF9AA3B8);
const explosiveColor = Color(0xFFFF4D2E);

/// Each level gets its own sky and grid color, so consecutive levels look different.
class LevelTheme {
  const LevelTheme(this.top, this.bottom, this.grid, this.accent);

  final Color top;
  final Color bottom;
  final Color grid;
  final Color accent;
}

const _themes = <LevelTheme>[
  LevelTheme(Color(0xFF0B0620), Color(0xFF2A0B3D), Color(0xFFFF2E97), Color(0xFF22E6FF)), // synthwave
  LevelTheme(Color(0xFF02101A), Color(0xFF052E3A), Color(0xFF22E6FF), Color(0xFFFFE14D)), // deep sea
  LevelTheme(Color(0xFF0F0A02), Color(0xFF3A1C05), Color(0xFFFF8A2E), Color(0xFF22E6FF)), // ember
  LevelTheme(Color(0xFF03120A), Color(0xFF0A3320), Color(0xFF3DFF8A), Color(0xFFFF2E97)), // matrix
  LevelTheme(Color(0xFF0D0418), Color(0xFF1E0A4A), Color(0xFF8B5CFF), Color(0xFF3DFF8A)), // violet
  LevelTheme(Color(0xFF14040A), Color(0xFF3D0A1E), Color(0xFFFF4D6D), Color(0xFFFFE14D)), // crimson
  LevelTheme(Color(0xFF050A14), Color(0xFF14233D), Color(0xFF7DD3FC), Color(0xFFFF8A2E)), // ice
];

/// Bosses always fight under a red sky.
const _bossTheme = LevelTheme(Color(0xFF120202), Color(0xFF3A0610), Color(0xFFFF3B3B), Color(0xFF22E6FF));

LevelTheme themeFor(int level) => level % 5 == 0 ? _bossTheme : _themes[(level - level ~/ 5 - 1) % _themes.length];

TextStyle display(double size, {Color color = ink}) => TextStyle(
  fontSize: size,
  fontWeight: FontWeight.w900,
  letterSpacing: size * 0.08,
  color: color,
  shadows: [Shadow(color: color.withValues(alpha: 0.8), blurRadius: size * 0.5)],
);
