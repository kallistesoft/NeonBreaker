import 'dart:math';

import 'model.dart';

enum BossKind { sentinel, hive, prism, titan }

extension BossInfo on BossKind {
  String get title => switch (this) {
    BossKind.sentinel => 'The Sentinel',
    BossKind.hive => 'The Hive',
    BossKind.prism => 'The Prism',
    BossKind.titan => 'The Titan',
  };

  String get hint => switch (this) {
    BossKind.sentinel => 'It sweeps and fires. Dodge the red shots.',
    BossKind.hive => 'It breeds armor. Break through fast.',
    BossKind.prism => 'Orbiting shields guard the core. Time your shots.',
    BossKind.titan => 'Huge, relentless, and it gets angry.',
  };
}

class BrickSpec {
  const BrickSpec(this.col, this.row, this.kind, this.hp);

  final int col;
  final int row;
  final BrickKind kind;
  final int hp;
}

class LevelSpec {
  const LevelSpec({
    required this.number,
    required this.name,
    required this.bricks,
    required this.boss,
    required this.bossHp,
    required this.bossPower,
    required this.ballSpeed,
    required this.paddleWidth,
    required this.drift,
    required this.powerUpChance,
    required this.badPowerUpShare,
  });

  final int number;
  final String name;
  final List<BrickSpec> bricks;
  final BossKind? boss;
  final int bossHp;

  /// Boss aggression multiplier: fire rate and speed, 1.0 for the first boss.
  final double bossPower;
  final double ballSpeed;
  final double paddleWidth;

  /// Amplitude of the brick formation's horizontal sway (0 = static).
  final double drift;
  final double powerUpChance;
  final double badPowerUpShare;

  bool get isBoss => boss != null;

  /// Index into the UI's color themes.
  int get theme => number;
}

bool isBossLevel(int n) => n % 5 == 0;

/// Last level start the player falls back to after a game over: the level after the last boss beaten.
int checkpointFor(int level) => level - (level - 1) % 5;

/// Brick patterns, 10 columns wide. `#` brick, `S` steel (from level 4), `X` explosive (from level 3),
/// Waves and Scatter are generated per level.
const _patterns = <String, List<String>>{
  'Pyramid': ['....##....', '...####...', '..######..', '.########.', '##########', '##X####X##'],
  'Wall': ['##########', '##########', '##########', '##########', '##########'],
  'Checkers': ['#.#.#.#.#.', '.#.#.#.#.#', '#.#.#.#.#.', '.#.#.#.#.#', '#.#.#.#.#.', '.#.#.#.#.#', '#.#.#.#.#.'],
  'Invader': ['..#....#..', '...#..#...', '..######..', '.##X##X##.', '##########', '#.######.#', '#.#....#.#', '...##.##..'],
  'Diamond': ['....##....', '...####...', '..##XX##..', '.###SS###.', '..##XX##..', '...####...', '....##....'],
  'Pillars': ['##..##..##', '##..##..##', '##..##..##', '##..##..##', '##..##..##', '##..##..##', 'SS..SS..SS'],
  'Chevrons': [
    '#........#',
    '##......##',
    '.##....##.',
    '..##..##..',
    '...#XX#...',
    '#...##...#',
    '##......##',
    '.##....##.',
    '..##..##..',
    '...####...',
  ],
  'Skull': ['..######..', '.########.', '##..##..##', '##..##..##', '####XX####', '.###..###.', '..#.##.#..', '..######..'],
  'Towers': ['.###..###.', '.#X#..#X#.', '.###..###.', '.###..###.', '.###..###.', '.SSS..SSS.'],
  'Rings': ['##########', '#........#', '#.######.#', '#.#XXXX#.#', '#.######.#', '#........#', '##########'],
  'Waves': [],
  'Cross': ['##......##', '.##....##.', '..##..##..', '...XXXX...', '..##..##..', '.##....##.', '##......##'],
  'Stairs': ['#.........', '##........', '###.......', '####......', '#####X....', '######....', '#######...', '########..', 'SSSSSSSSS.'],
  'Fortress': ['S########S', 'S#......#S', 'S#.XXXX.#S', 'S#.XXXX.#S', 'S#......#S', 'SSSS..SSSS'],
  'Maze': ['##S####S##', '#........#', '#.##SS##.#', '#.#....#.#', '#.#.XX.#.#', '#........#', '##########'],
  'Scatter': [],
};

/// The first 16 regular levels in a hand-picked order (easy shapes first); later cycles are shuffled.
const _firstCycle = [
  'Pyramid', 'Wall', 'Checkers', 'Invader', //
  'Diamond', 'Pillars', 'Chevrons', 'Skull',
  'Towers', 'Rings', 'Waves', 'Cross',
  'Stairs', 'Fortress', 'Maze', 'Scatter',
];

String _patternFor(int regularIndex) {
  final cycle = regularIndex ~/ _firstCycle.length;
  final i = regularIndex % _firstCycle.length;
  if (cycle == 0) return _firstCycle[i];
  final order = List.of(_firstCycle)..shuffle(Random(cycle * 7919));
  // Never repeat the previous level's shape across a cycle boundary.
  if (i == 0 && order.first == _patternFor(regularIndex - 1)) order.add(order.removeAt(0));
  return order[i];
}

LevelSpec buildLevel(int n) {
  assert(n >= 1);
  final rng = Random(n * 104729);
  final bossIndex = n ~/ 5;
  final ballSpeed = min(520.0, 270.0 + 9.0 * (n - 1));
  final paddleWidth = max(54.0, 86.0 - 1.1 * (n - 1));
  final badShare = min(0.35, 0.04 + n * 0.012);

  if (isBossLevel(n)) {
    final kind = BossKind.values[(bossIndex - 1) % BossKind.values.length];
    return LevelSpec(
      number: n,
      name: kind.title,
      bricks: const [],
      boss: kind,
      bossHp: 20 + 6 * (bossIndex - 1),
      bossPower: 1 + 0.15 * (bossIndex - 1),
      ballSpeed: ballSpeed,
      paddleWidth: paddleWidth,
      drift: 0,
      powerUpChance: 0.35,
      badPowerUpShare: badShare * 0.5,
    );
  }

  final regularIndex = n - bossIndex - 1;
  final name = _patternFor(regularIndex);
  var rows = _expand(name, rng);
  if (rng.nextBool()) rows = [for (final r in rows) r.split('').reversed.join()];
  // Later levels push the formation lower, closer to the paddle.
  final rowOffset = min(4, (n - 1) ~/ 12) + (n > 20 ? rng.nextInt(2) : 0);

  final maxHp = min(5, 1 + (n - 1) ~/ 4);
  final steelChance = n >= 10 ? min(0.12, (n - 9) * 0.01) : 0.0;
  final bricks = <BrickSpec>[];
  for (var r = 0; r < rows.length; r++) {
    for (var c = 0; c < gridCols; c++) {
      final ch = rows[r][c];
      if (ch == '.') continue;
      final row = r + rowOffset;
      if (bricks.any((b) => b.col == c && b.row == row)) continue; // the mirror of a steel brick
      if (ch == 'S' && n >= 4) {
        bricks.add(BrickSpec(c, row, BrickKind.steel, 1));
      } else if (ch == 'X' && n >= 3) {
        bricks.add(BrickSpec(c, row, BrickKind.explosive, 1));
      } else if (steelChance > 0 && c < gridCols ~/ 2 && rng.nextDouble() < steelChance) {
        // Mirrored pair of steel, so the shape stays symmetric.
        bricks.add(BrickSpec(c, row, BrickKind.steel, 1));
        if (rows[r][gridCols - 1 - c] != '.') bricks.add(BrickSpec(gridCols - 1 - c, row, BrickKind.steel, 1));
      } else {
        final base = maxHp - (r * maxHp) ~/ rows.length;
        bricks.add(BrickSpec(c, row, BrickKind.normal, max(1, base - rng.nextInt(2))));
      }
    }
  }

  final regularLevelsDone = regularIndex;
  final drift = n >= 7 && regularLevelsDone % 3 == 1 ? min(40.0, 14.0 + n * 0.8) : 0.0;
  return LevelSpec(
    number: n,
    name: name,
    bricks: _ensureReachable(bricks),
    boss: null,
    bossHp: 0,
    bossPower: 1,
    ballSpeed: ballSpeed,
    paddleWidth: paddleWidth,
    drift: drift,
    powerUpChance: 0.13,
    badPowerUpShare: badShare,
  );
}

List<String> _expand(String name, Random rng) {
  if (name == 'Waves') {
    // Two bands following a sine, a different phase each time.
    final phase = rng.nextDouble() * pi * 2;
    return [
      for (var r = 0; r < 8; r++)
        [
          for (var c = 0; c < gridCols; c++)
            switch (r - (2.5 + 2.2 * sin(c * 0.75 + phase))) {
              final d when d >= 0 && d < 1 => rng.nextDouble() < 0.15 ? 'X' : '#',
              final d when d >= 1 && d < 2.2 => '#',
              _ => '.',
            },
        ].join(),
    ];
  }
  if (name == 'Scatter') {
    // Random symmetric fill: half the columns are drawn, then mirrored.
    final rows = <String>[];
    for (var r = 0; r < 8; r++) {
      final half = [for (var c = 0; c < 5; c++) rng.nextDouble() < 0.6 ? (rng.nextDouble() < 0.08 ? 'X' : '#') : '.'];
      rows.add([...half, ...half.reversed].join());
    }
    return rows;
  }
  return _patterns[name]!;
}

/// Steel can't be broken, so it must never seal breakable bricks off from the ball.
/// Flood-fill from outside the formation through everything but steel; if a breakable
/// brick is unreachable, the steel becomes ordinary bricks.
List<BrickSpec> _ensureReachable(List<BrickSpec> bricks) {
  final steel = {for (final b in bricks.where((b) => b.kind == BrickKind.steel)) (b.col, b.row)};
  if (steel.isEmpty) return bricks;
  final maxRow = bricks.map((b) => b.row).reduce(max) + 1;
  final seen = <(int, int)>{};
  final queue = <(int, int)>[];
  for (var c = -1; c <= gridCols; c++) {
    queue.add((c, maxRow));
  }
  while (queue.isNotEmpty) {
    final cell = queue.removeLast();
    final (c, r) = cell;
    if (c < -1 || c > gridCols || r < -1 || r > maxRow) continue;
    if (steel.contains(cell) || !seen.add(cell)) continue;
    queue.addAll([(c + 1, r), (c - 1, r), (c, r + 1), (c, r - 1)]);
  }
  final sealed = bricks.any((b) => b.kind != BrickKind.steel && !seen.contains((b.col, b.row)));
  if (!sealed) return bricks;
  return [for (final b in bricks) b.kind == BrickKind.steel ? BrickSpec(b.col, b.row, BrickKind.normal, 2) : b];
}
