import 'dart:ui';

/// The playfield is a fixed 360×640 world; the UI scales it to the screen.
const worldW = 360.0;
const worldH = 640.0;

/// Top of the playfield (the HUD sits above it).
const fieldTop = 44.0;

/// Brick grid: 10 columns of 30-wide bricks with 2-unit gaps, centered, leaving room
/// for the ball to pass down the sides.
const gridCols = 10;
const brickW = 30.0;
const brickH = 14.0;
const colStep = 32.0;
const rowStep = 17.0;
const gridLeft = (worldW - (colStep * (gridCols - 1) + brickW)) / 2;
const gridTop = 78.0;

const paddleY = 584.0;
const paddleH = 12.0;
const ballRadius = 6.0;

enum BrickKind { normal, steel, explosive }

class Brick {
  Brick({required this.col, required this.row, required this.kind, required this.hp}) : maxHp = hp;

  final int col;
  final int row;
  final BrickKind kind;
  final int maxHp;
  int hp;

  /// Seconds left on the hit flash.
  double flash = 0;

  bool get alive => hp > 0;
  bool get breakable => kind != BrickKind.steel;

  Rect rect(double dx, double dy) => Rect.fromLTWH(gridLeft + col * colStep + dx, gridTop + row * rowStep + dy, brickW, brickH);
}

class Ball {
  Ball(this.pos, this.vel);

  Offset pos;
  Offset vel;

  /// While stuck the ball rides the paddle at this horizontal offset.
  bool stuck = false;
  double stuckOffset = 0;
}

enum PowerKind {
  wide,
  multi,
  laser,
  slow,
  life,
  // Bad ones, more frequent in later levels.
  shrink,
  fast,
}

extension PowerKindInfo on PowerKind {
  bool get bad => this == PowerKind.shrink || this == PowerKind.fast;

  String get label => switch (this) {
    PowerKind.wide => 'W',
    PowerKind.multi => 'M',
    PowerKind.laser => 'L',
    PowerKind.slow => 'S',
    PowerKind.life => '+',
    PowerKind.shrink => '-',
    PowerKind.fast => 'F',
  };
}

class PowerUp {
  PowerUp(this.kind, this.pos);

  final PowerKind kind;
  Offset pos;

  Rect get rect => Rect.fromCenter(center: pos, width: 26, height: 13);
}

/// Something moving in a straight line: boss shots (down) and paddle lasers (up).
class Shot {
  Shot(this.pos, this.vel);

  Offset pos;
  final Offset vel;
  bool dead = false;
}

enum EventType {
  launch,
  paddle,
  wall,
  brickHit,
  brickBreak,
  steel,
  explode,
  powerUp,
  badPowerUp,
  laser,
  bossHit,
  bossShoot,
  bossDown,
  stunned,
  ballLost,
  lifeLost,
  levelClear,
  gameOver,
}

/// What happened during a step, for sound and particles.
class GameEvent {
  const GameEvent(this.type, [this.pos = Offset.zero, this.tag = 0, this.row = 0]);

  final EventType type;
  final Offset pos;

  /// Extra detail for the UI, e.g. the broken brick's max hp (its sound).
  final int tag;

  /// Grid row of the brick involved (its color).
  final int row;
}
