import 'dart:math';
import 'dart:ui';

import 'levels.dart';
import 'model.dart';

enum WorldState { playing, winning, won, lost }

class Boss {
  Boss(this.kind, this.maxHp, this.power)
    : hp = maxHp,
      size = switch (kind) {
        BossKind.sentinel => const Size(110, 34),
        BossKind.hive => const Size(96, 44),
        BossKind.prism => const Size(60, 60),
        BossKind.titan => const Size(150, 52),
      },
      center = Offset(worldW / 2, kind == BossKind.prism ? 175 : 115);

  final BossKind kind;
  final int maxHp;
  final double power;
  final Size size;
  int hp;
  Offset center;
  double t = 0;
  double fireTimer = 1.5;
  double spawnTimer = 3;
  double flash = 0;

  bool get enraged => hp * 2 < maxHp;
  Rect get rect => Rect.fromCenter(center: center, width: size.width, height: size.height);

  /// Prism only: shields orbiting the core.
  List<Rect> get shields {
    if (kind != BossKind.prism) return const [];
    final count = enraged ? 5 : 6;
    return [
      for (var i = 0; i < count; i++)
        Rect.fromCenter(center: center + Offset.fromDirection(t * 1.1 * power + i * 2 * pi / count, 66), width: 22, height: 22),
    ];
  }
}

/// One level in play: the whole simulation, independent of rendering.
class GameWorld {
  GameWorld(this.spec, {required this.lives, required this.score, int? seed})
    : _rng = Random(seed ?? spec.number),
      paddleX = worldW / 2,
      paddleTarget = worldW / 2 {
    bricks = [for (final b in spec.bricks) Brick(col: b.col, row: b.row, kind: b.kind, hp: b.hp)];
    if (spec.boss != null) boss = Boss(spec.boss!, spec.bossHp, spec.bossPower);
    _driftAmp = _driftRoom();
    _serve();
  }

  final LevelSpec spec;
  final Random _rng;
  int lives;
  int score;
  int combo = 0;
  int bestCombo = 0;
  int bricksBroken = 0;

  late final List<Brick> bricks;
  Boss? boss;
  final balls = <Ball>[];
  final powerUps = <PowerUp>[];
  final bossShots = <Shot>[];
  final lasers = <Shot>[];

  /// Seconds left on each active power-up.
  final effects = <PowerKind, double>{};

  double paddleX;
  double paddleTarget;
  double stun = 0;
  double time = 0;
  int _paddleHits = 0;
  double _laserTimer = 0;
  double _winTimer = 0;
  late final double _driftAmp;

  WorldState state = WorldState.playing;
  final events = <GameEvent>[];

  static const maxBalls = 9;
  static const maxLives = 6;

  double get paddleWidth {
    var w = spec.paddleWidth;
    if (effects.containsKey(PowerKind.wide)) w *= 1.5;
    if (effects.containsKey(PowerKind.shrink)) w *= 0.7;
    return w;
  }

  Rect get paddleRect => Rect.fromCenter(center: Offset(paddleX, paddleY + paddleH / 2), width: paddleWidth, height: paddleH);

  double get ballSpeed {
    var s = spec.ballSpeed * (1 + min(0.2, _paddleHits * 0.01));
    if (effects.containsKey(PowerKind.slow)) s *= 0.72;
    if (effects.containsKey(PowerKind.fast)) s *= 1.22;
    return s;
  }

  Offset get brickOffset => Offset(_driftAmp * sin(time * 0.9), 0);

  bool get hasStuckBall => balls.any((b) => b.stuck);

  int get bricksLeft => bricks.where((b) => b.alive && b.breakable).length;

  /// How far the formation can sway without leaving the field.
  double _driftRoom() {
    if (spec.drift == 0 || bricks.isEmpty) return 0;
    final minCol = bricks.map((b) => b.col).reduce(min);
    final maxCol = bricks.map((b) => b.col).reduce(max);
    final left = gridLeft + minCol * colStep - 3;
    final right = worldW - (gridLeft + maxCol * colStep + brickW) - 3;
    return min(spec.drift, min(left, right));
  }

  void _serve() {
    balls.add(
      Ball(Offset(paddleX, paddleY - ballRadius - 1), Offset.zero)
        ..stuck = true
        ..stuckOffset = 0,
    );
  }

  void movePaddleTo(double x) => paddleTarget = x;

  void launch() {
    if (state != WorldState.playing) return;
    for (final b in balls.where((b) => b.stuck)) {
      b.stuck = false;
      final rel = b.stuckOffset / (paddleWidth / 2);
      final angle = rel.abs() < 0.05 ? (_rng.nextBool() ? 0.25 : -0.25) : rel * 0.9;
      b.vel = Offset(sin(angle), -cos(angle)) * ballSpeed;
      events.add(GameEvent(EventType.launch, b.pos));
    }
  }

  void update(double dt) {
    if (state == WorldState.won || state == WorldState.lost) return;
    dt = min(dt, 1 / 30);
    time += dt;
    if (state == WorldState.winning) {
      _winTimer -= dt;
      if (_winTimer <= 0) {
        state = WorldState.won;
        events.add(const GameEvent(EventType.levelClear));
      }
      return;
    }

    _updateEffects(dt);
    _updatePaddle(dt);
    for (final b in bricks) {
      if (b.flash > 0) b.flash -= dt;
    }
    if (boss != null) _updateBoss(dt);
    _updateBalls(dt);
    _updateLasers(dt);
    _updatePowerUps(dt);
    _updateBossShots(dt);
    _checkWin();
  }

  void _updateEffects(double dt) {
    for (final k in effects.keys.toList()) {
      final left = effects[k]! - dt;
      if (left <= 0) {
        effects.remove(k);
      } else {
        effects[k] = left;
      }
    }
    if (stun > 0) stun -= dt;
  }

  void _updatePaddle(double dt) {
    final half = paddleWidth / 2;
    if (stun <= 0) {
      final target = paddleTarget.clamp(half, worldW - half);
      final step = 1600 * dt;
      paddleX += (target - paddleX).clamp(-step, step);
    }
    paddleX = paddleX.clamp(half, worldW - half);
    for (final b in balls.where((b) => b.stuck)) {
      b.stuckOffset = b.stuckOffset.clamp(-half + ballRadius, half - ballRadius);
      b.pos = Offset(paddleX + b.stuckOffset, paddleY - ballRadius - 1);
    }

    if (effects.containsKey(PowerKind.laser)) {
      _laserTimer -= dt;
      if (_laserTimer <= 0) {
        _laserTimer = 0.32;
        lasers.add(Shot(Offset(paddleX - half + 6, paddleY - 2), const Offset(0, -560)));
        lasers.add(Shot(Offset(paddleX + half - 6, paddleY - 2), const Offset(0, -560)));
        events.add(GameEvent(EventType.laser, Offset(paddleX, paddleY)));
      }
    }
  }

  void _updateBalls(double dt) {
    final speed = ballSpeed;
    for (final ball in List.of(balls)) {
      if (ball.stuck) continue;
      ball.vel = _normalized(ball.vel, speed);
      final distance = speed * dt;
      final steps = max(1, (distance / 4).ceil());
      final sdt = dt / steps;
      for (var i = 0; i < steps; i++) {
        ball.pos += ball.vel * sdt;
        if (_collideWalls(ball) || _collidePaddle(ball)) continue;
        if (_collideBricks(ball)) continue;
        if (boss != null) _collideBoss(ball);
      }
      if (ball.pos.dy - ballRadius > worldH) {
        balls.remove(ball);
        events.add(GameEvent(EventType.ballLost, Offset(ball.pos.dx, worldH)));
      }
    }
    if (balls.isEmpty) _loseLife();
  }

  /// Keeps the speed constant and the path from going nearly flat (endless side-to-side bounces).
  Offset _normalized(Offset v, double speed) {
    if (v.distance == 0) return Offset(0, -speed);
    var d = v / v.distance;
    const minVertical = 0.28;
    if (d.dy.abs() < minVertical) {
      final sy = d.dy >= 0 ? 1.0 : -1.0;
      d = Offset(d.dx.sign * sqrt(1 - minVertical * minVertical), sy * minVertical);
    }
    return d * speed;
  }

  bool _collideWalls(Ball b) {
    var hit = false;
    if (b.pos.dx < ballRadius && b.vel.dx < 0) {
      b.pos = Offset(ballRadius, b.pos.dy);
      b.vel = Offset(-b.vel.dx, b.vel.dy);
      hit = true;
    } else if (b.pos.dx > worldW - ballRadius && b.vel.dx > 0) {
      b.pos = Offset(worldW - ballRadius, b.pos.dy);
      b.vel = Offset(-b.vel.dx, b.vel.dy);
      hit = true;
    }
    if (b.pos.dy < fieldTop + ballRadius && b.vel.dy < 0) {
      b.pos = Offset(b.pos.dx, fieldTop + ballRadius);
      b.vel = Offset(b.vel.dx, -b.vel.dy);
      hit = true;
    }
    if (hit) events.add(GameEvent(EventType.wall, b.pos));
    return hit;
  }

  bool _collidePaddle(Ball b) {
    if (b.vel.dy <= 0) return false;
    final p = paddleRect;
    if (b.pos.dy + ballRadius < p.top || b.pos.dy > p.bottom) return false;
    if (b.pos.dx < p.left - ballRadius || b.pos.dx > p.right + ballRadius) return false;
    // The hit position sets the angle: center goes straight up, edges up to 62°.
    final rel = ((b.pos.dx - paddleX) / (p.width / 2)).clamp(-1.0, 1.0);
    final angle = rel * 62 * pi / 180;
    b.vel = Offset(sin(angle), -cos(angle)) * ballSpeed;
    b.pos = Offset(b.pos.dx, p.top - ballRadius);
    combo = 0;
    _paddleHits++;
    events.add(GameEvent(EventType.paddle, b.pos));
    return true;
  }

  /// Bounces [b] off [r] if they overlap. Returns true on a hit.
  bool _bounce(Ball b, Rect r) {
    final cx = b.pos.dx.clamp(r.left, r.right);
    final cy = b.pos.dy.clamp(r.top, r.bottom);
    var n = b.pos - Offset(cx, cy);
    final d = n.distance;
    if (d >= ballRadius) return false;
    if (d == 0) {
      // Center inside the rect: push out along the shallowest side.
      final pens = [b.pos.dx - r.left, r.right - b.pos.dx, b.pos.dy - r.top, r.bottom - b.pos.dy];
      final m = pens.indexOf(pens.reduce(min));
      n = const [Offset(-1, 0), Offset(1, 0), Offset(0, -1), Offset(0, 1)][m];
      b.pos = switch (m) {
        0 => Offset(r.left - ballRadius, b.pos.dy),
        1 => Offset(r.right + ballRadius, b.pos.dy),
        2 => Offset(b.pos.dx, r.top - ballRadius),
        _ => Offset(b.pos.dx, r.bottom + ballRadius),
      };
    } else {
      n = n / d;
      b.pos = Offset(cx, cy) + n * ballRadius;
    }
    if (n.dx.abs() > n.dy.abs()) {
      if (b.vel.dx * n.dx < 0) b.vel = Offset(-b.vel.dx, b.vel.dy);
    } else {
      if (b.vel.dy * n.dy < 0) b.vel = Offset(b.vel.dx, -b.vel.dy);
    }
    return true;
  }

  bool _collideBricks(Ball ball) {
    final off = brickOffset;
    for (final brick in bricks) {
      if (!brick.alive) continue;
      if (_bounce(ball, brick.rect(off.dx, off.dy))) {
        _hitBrick(brick, 1);
        return true;
      }
    }
    return false;
  }

  /// Steel and shields nudge the angle a little, so the ball can't lock into a loop it never leaves.
  void _jitter() {
    for (final b in balls) {
      if (b.stuck) continue;
      final a = (_rng.nextDouble() - 0.5) * 0.12;
      b.vel = Offset(b.vel.dx * cos(a) - b.vel.dy * sin(a), b.vel.dx * sin(a) + b.vel.dy * cos(a));
    }
  }

  void _hitBrick(Brick brick, int damage) {
    final center = brick.rect(brickOffset.dx, brickOffset.dy).center;
    brick.flash = 0.12;
    if (!brick.breakable) {
      events.add(GameEvent(EventType.steel, center));
      _jitter();
      return;
    }
    brick.hp -= damage;
    if (brick.hp > 0) {
      events.add(GameEvent(EventType.brickHit, center, brick.maxHp, brick.row));
      return;
    }
    _breakBrick(brick);
  }

  void _breakBrick(Brick brick) {
    final center = brick.rect(brickOffset.dx, brickOffset.dy).center;
    brick.hp = 0;
    combo++;
    bestCombo = max(bestCombo, combo);
    bricksBroken++;
    score += (10 * brick.maxHp * (1 + min(combo, 20) * 0.1)).round();
    events.add(GameEvent(EventType.brickBreak, center, brick.maxHp, brick.row));
    _maybeDrop(center, spec.powerUpChance);
    if (brick.kind == BrickKind.explosive) {
      events.add(GameEvent(EventType.explode, center));
      for (final other in bricks) {
        if (other.alive && other.breakable && (other.col - brick.col).abs() <= 1 && (other.row - brick.row).abs() <= 1) {
          _breakBrick(other);
        }
      }
    }
  }

  void _maybeDrop(Offset at, double chance) {
    if (_rng.nextDouble() >= chance) return;
    PowerKind kind;
    if (_rng.nextDouble() < spec.badPowerUpShare) {
      kind = _rng.nextBool() ? PowerKind.shrink : PowerKind.fast;
    } else {
      final r = _rng.nextDouble();
      kind = r < 0.05
          ? PowerKind.life
          : r < 0.32
          ? PowerKind.wide
          : r < 0.56
          ? PowerKind.multi
          : r < 0.8
          ? PowerKind.laser
          : PowerKind.slow;
    }
    powerUps.add(PowerUp(kind, at));
  }

  void _updatePowerUps(double dt) {
    final p = paddleRect;
    for (final pu in List.of(powerUps)) {
      pu.pos += Offset(0, 115 * dt);
      if (pu.rect.overlaps(p)) {
        powerUps.remove(pu);
        _apply(pu.kind);
      } else if (pu.pos.dy > worldH + 20) {
        powerUps.remove(pu);
      }
    }
  }

  void _apply(PowerKind kind) {
    events.add(GameEvent(kind.bad ? EventType.badPowerUp : EventType.powerUp, Offset(paddleX, paddleY), kind.index));
    switch (kind) {
      case PowerKind.wide:
        effects.remove(PowerKind.shrink);
        effects[kind] = 15;
      case PowerKind.shrink:
        effects.remove(PowerKind.wide);
        effects[kind] = 10;
      case PowerKind.slow:
        effects.remove(PowerKind.fast);
        effects[kind] = 10;
      case PowerKind.fast:
        effects.remove(PowerKind.slow);
        effects[kind] = 8;
      case PowerKind.laser:
        effects[kind] = 10;
      case PowerKind.life:
        lives = min(maxLives, lives + 1);
      case PowerKind.multi:
        for (final b in List.of(balls)) {
          final base = b.stuck ? Offset(0, -ballSpeed) : b.vel;
          for (final a in const [-0.4, 0.4]) {
            if (balls.length >= maxBalls) break;
            final v = Offset(base.dx * cos(a) - base.dy * sin(a), base.dx * sin(a) + base.dy * cos(a));
            balls.add(Ball(b.pos, v.dy > 0 ? Offset(v.dx, -v.dy) : v));
          }
        }
    }
  }

  void _updateLasers(double dt) {
    final off = brickOffset;
    for (final s in lasers) {
      s.pos += s.vel * dt;
      if (s.pos.dy < fieldTop) {
        s.dead = true;
        continue;
      }
      for (final brick in bricks) {
        if (brick.alive && brick.rect(off.dx, off.dy).contains(s.pos)) {
          _hitBrick(brick, 1);
          s.dead = true;
          break;
        }
      }
      final bo = boss;
      if (!s.dead && bo != null && bo.hp > 0) {
        if (bo.shields.any((r) => r.contains(s.pos))) {
          s.dead = true;
        } else if (bo.rect.contains(s.pos)) {
          s.dead = true;
          _damageBoss(1, s.pos);
        }
      }
    }
    lasers.removeWhere((s) => s.dead);
  }

  // ---- Boss ----

  void _updateBoss(double dt) {
    final b = boss!;
    if (b.hp <= 0) return;
    b.t += dt;
    if (b.flash > 0) b.flash -= dt;
    final p = b.power;
    switch (b.kind) {
      case BossKind.sentinel:
        b.center = Offset(worldW / 2 + 115 * sin(b.t * 0.85 * p), b.center.dy);
        b.fireTimer -= dt;
        if (b.fireTimer <= 0) {
          b.fireTimer = (b.enraged ? 1.0 : 1.5) / p;
          _aimShot(b.rect.bottomCenter, 0, 210 * sqrt(p));
        }
      case BossKind.hive:
        b.center = Offset(worldW / 2 + 70 * sin(b.t * 0.5 * p), b.center.dy);
        b.fireTimer -= dt;
        if (b.fireTimer <= 0) {
          b.fireTimer = 2.6 / p;
          for (final a in const [-0.35, 0.0, 0.35]) {
            _aimShot(b.rect.bottomCenter, a, 180 * sqrt(p));
          }
        }
        b.spawnTimer -= dt;
        if (b.spawnTimer <= 0) {
          b.spawnTimer = (b.enraged ? 5.0 : 7.0) / p;
          _spawnArmor();
        }
      case BossKind.prism:
        b.center = Offset(worldW / 2 + 60 * sin(b.t * 0.4), b.center.dy);
        b.fireTimer -= dt;
        if (b.fireTimer <= 0) {
          b.fireTimer = (b.enraged ? 1.4 : 2.1) / p;
          _aimShot(b.center, 0, 200 * sqrt(p));
        }
      case BossKind.titan:
        final rage = b.enraged ? 1.7 : 1.0;
        b.center = Offset(worldW / 2 + 85 * sin(b.t * 0.55 * p * rage), min(250, 115 + b.t * 3));
        b.fireTimer -= dt;
        if (b.fireTimer <= 0) {
          b.fireTimer = (b.enraged ? 1.5 : 2.4) / p;
          for (final a in const [-0.22, 0.0, 0.22]) {
            _aimShot(b.rect.bottomCenter, a, 190 * sqrt(p) * rage);
          }
        }
    }
  }

  void _aimShot(Offset from, double spread, double speed) {
    final dir = Offset(paddleX, paddleY) - from;
    final a = atan2(dir.dy, dir.dx) + spread;
    bossShots.add(Shot(from, Offset.fromDirection(a, speed)));
    events.add(GameEvent(EventType.bossShoot, from));
  }

  /// Hive: refills a row of armor bricks below itself.
  void _spawnArmor() {
    const row = 4;
    final hp = boss!.enraged ? 2 : 1;
    var spawned = 0;
    for (var c = 1; c < gridCols - 1; c++) {
      if (bricks.any((b) => b.alive && b.col == c && b.row == row)) continue;
      bricks.add(Brick(col: c, row: row, kind: BrickKind.normal, hp: hp));
      spawned++;
    }
    if (spawned > 0) events.add(GameEvent(EventType.bossShoot, boss!.center));
  }

  void _collideBoss(Ball ball) {
    final b = boss!;
    if (b.hp <= 0) return;
    for (final s in b.shields) {
      if (_bounce(ball, s)) {
        events.add(GameEvent(EventType.steel, s.center));
        _jitter();
        return;
      }
    }
    if (_bounce(ball, b.rect)) _damageBoss(1, ball.pos);
  }

  void _damageBoss(int damage, Offset at) {
    final b = boss!;
    b.hp = max(0, b.hp - damage);
    b.flash = 0.1;
    score += 20;
    events.add(GameEvent(EventType.bossHit, at));
    if (b.hp == 0) {
      score += 500 * (spec.number ~/ 5);
      events.add(GameEvent(EventType.bossDown, b.center));
      for (final brick in bricks) {
        brick.hp = 0;
      }
      bossShots.clear();
    }
  }

  void _updateBossShots(double dt) {
    final p = paddleRect;
    for (final s in bossShots) {
      s.pos += s.vel * dt;
      if (s.pos.dy > worldH + 10 || s.pos.dx < -10 || s.pos.dx > worldW + 10) {
        s.dead = true;
      } else if (p.inflate(4).contains(s.pos)) {
        s.dead = true;
        if (stun <= 0) {
          stun = 0.7;
          events.add(GameEvent(EventType.stunned, s.pos));
        }
      }
    }
    bossShots.removeWhere((s) => s.dead);
  }

  // ---- Lives and winning ----

  void _loseLife() {
    lives--;
    combo = 0;
    powerUps.clear();
    bossShots.clear();
    lasers.clear();
    effects.clear();
    stun = 0;
    if (lives <= 0) {
      lives = 0;
      state = WorldState.lost;
      events.add(const GameEvent(EventType.gameOver));
      return;
    }
    events.add(const GameEvent(EventType.lifeLost));
    _serve();
  }

  void _checkWin() {
    final won = boss != null ? boss!.hp <= 0 : bricksLeft == 0;
    if (!won) return;
    state = WorldState.winning;
    _winTimer = boss != null ? 1.6 : 0.8;
    score += clearBonus;
    balls.clear();
    powerUps.clear();
    lasers.clear();
  }

  int get clearBonus => 100 * spec.number + 50 * lives;
}
