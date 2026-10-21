import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../game/levels.dart';
import '../game/model.dart';
import '../game/world.dart';
import '../services/progress_store.dart';
import '../services/sound_service.dart';
import 'effects.dart';
import 'overlays.dart';
import 'palette.dart';
import 'services.dart';
import 'world_painter.dart';

enum Phase { playing, paused, intermission, gameOver }

/// A run: plays levels one after another, with the intermission (ad slot) between them.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.run});

  final SavedRun run;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late GameWorld world;
  final effects = Effects();
  final frame = ValueNotifier<int>(0);
  late final Ticker _ticker;
  final _focus = FocusNode();
  final _held = <LogicalKeyboardKey>{};
  Duration? _last;
  Phase phase = Phase.playing;
  double introTime = 0;
  LevelResult? result;
  bool _started = false;

  Services get services => Services.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    world = GameWorld(buildLevel(widget.run.level), lives: widget.run.lives, score: widget.run.score);
    _ticker = createTicker(_tick)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      unawaited(services.progress.saveRun(widget.run));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _focus.dispose();
    frame.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && phase == Phase.playing) setState(() => phase = Phase.paused);
  }

  void _tick(Duration elapsed) {
    final dt = _last == null ? 0.0 : (elapsed - _last!).inMicroseconds / 1e6;
    _last = elapsed;
    if (phase != Phase.playing) return;
    if (_held.contains(LogicalKeyboardKey.arrowLeft) || _held.contains(LogicalKeyboardKey.keyA)) {
      world.movePaddleTo(world.paddleX - 480 * dt);
    } else if (_held.contains(LogicalKeyboardKey.arrowRight) || _held.contains(LogicalKeyboardKey.keyD)) {
      world.movePaddleTo(world.paddleX + 480 * dt);
    }
    world.update(dt);
    introTime += dt;
    _handleEvents();
    effects.update(dt);
    frame.value++;
  }

  void _handleEvents() {
    final sound = services.sound;
    for (final e in world.events) {
      switch (e.type) {
        case EventType.launch:
          break;
        case EventType.paddle:
          sound.play(Sfx.paddle);
          effects.burst(e.pos, themeFor(world.spec.number).accent, count: 5, speed: 80, life: 0.3);
        case EventType.wall:
          sound.play(Sfx.wall);
        case EventType.brickHit:
          sound.play(Sfx.hit);
          effects.burst(e.pos, brickColor(world.spec.number, e.row), count: 5, speed: 90, life: 0.3);
        case EventType.brickBreak:
          sound.play(SoundService.breakFor(e.tag));
          effects.burst(e.pos, brickColor(world.spec.number, e.row), count: 14);
          if (world.combo >= 5 && world.combo % 5 == 0) {
            effects.popup('x${world.combo} COMBO', e.pos, neonYellow, size: 14);
          }
        case EventType.steel:
          sound.play(Sfx.steel);
          effects.burst(e.pos, steelColor, count: 4, speed: 70, life: 0.25);
        case EventType.explode:
          sound.play(Sfx.explode);
          effects.burst(e.pos, explosiveColor, count: 30, speed: 240, size: 3, life: 0.7);
          effects.addShake(5);
        case EventType.powerUp:
        case EventType.badPowerUp:
          final kind = PowerKind.values[e.tag];
          sound.play(kind.bad ? Sfx.bad : Sfx.powerup);
          effects.popup(_powerName(kind), e.pos - const Offset(0, 20), kind.bad ? danger : neonCyan, size: 14);
        case EventType.laser:
          sound.play(Sfx.laser);
        case EventType.bossHit:
          sound.play(Sfx.bosshit);
          effects.burst(e.pos, neonPink, count: 8, speed: 120);
          effects.addShake(1.5);
        case EventType.bossShoot:
          sound.play(Sfx.bossshoot);
        case EventType.bossDown:
          sound.play(Sfx.bossdown);
          for (var i = 0; i < 4; i++) {
            effects.burst(e.pos, [neonPink, neonYellow, neonCyan, danger][i], count: 40, speed: 120.0 + i * 70, size: 3.5, life: 1.3);
          }
          effects.addShake(10);
        case EventType.stunned:
          sound.play(Sfx.stun);
          effects.burst(e.pos, Colors.white, count: 12, speed: 150);
          effects.addShake(3);
        case EventType.ballLost:
          break;
        case EventType.lifeLost:
          sound.play(Sfx.lost);
          effects.addShake(4);
          HapticFeedback.mediumImpact();
        case EventType.levelClear:
          sound.play(Sfx.clear);
          _levelCleared();
        case EventType.gameOver:
          sound.play(Sfx.gameover);
          _gameOver();
      }
    }
    world.events.clear();
  }

  static String _powerName(PowerKind k) => switch (k) {
    PowerKind.wide => 'WIDE',
    PowerKind.multi => 'MULTI-BALL',
    PowerKind.laser => 'LASER',
    PowerKind.slow => 'SLOW',
    PowerKind.life => '+1 LIFE',
    PowerKind.shrink => 'SHRINK',
    PowerKind.fast => 'FAST',
  };

  void _levelCleared() {
    final progress = services.progress;
    final level = world.spec.number;
    result = LevelResult(level: level, score: world.score, bonus: world.clearBonus, bestCombo: world.bestCombo, bricks: world.bricksBroken);
    unawaited(progress.recordScore(world.score));
    if (world.spec.isBoss) unawaited(progress.recordBoss());
    unawaited(progress.saveRun(SavedRun(level: level + 1, score: world.score, lives: world.lives)));
    setState(() => phase = Phase.intermission);
  }

  void _gameOver() {
    final progress = services.progress;
    unawaited(progress.recordScore(world.score));
    unawaited(progress.clearRun());
    setState(() => phase = Phase.gameOver);
  }

  Future<void> _nextLevel() async {
    await services.ads.showInterstitial();
    if (!mounted) return;
    _startLevel(SavedRun(level: world.spec.number + 1, score: world.score, lives: world.lives));
  }

  void _startLevel(SavedRun run) {
    unawaited(services.progress.saveRun(run));
    setState(() {
      world = GameWorld(buildLevel(run.level), lives: run.lives, score: run.score);
      effects.clear();
      introTime = 0;
      phase = Phase.playing;
    });
    _focus.requestFocus();
  }

  void _togglePause() {
    if (phase == Phase.playing) {
      setState(() => phase = Phase.paused);
    } else if (phase == Phase.paused) {
      _last = null;
      setState(() => phase = Phase.playing);
      _focus.requestFocus();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (event is KeyUpEvent) {
      _held.remove(key);
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    _held.add(key);
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.arrowUp) {
      if (phase == Phase.playing) world.launch();
      if (phase == Phase.intermission) _nextLevel();
      if (phase == Phase.paused) _togglePause();
    } else if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.keyP) {
      _togglePause();
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = themeFor(world.spec.number);
    return PopScope(
      canPop: phase != Phase.playing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _togglePause();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: DecoratedBox(
          // Same sky as the playfield, so letterbox bars blend in on tall screens.
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [theme.top, theme.bottom]),
          ),
          child: Focus(
            focusNode: _focus,
            autofocus: true,
            onKeyEvent: _onKey,
            child: SafeArea(
              child: Center(
                child: AspectRatio(
                  aspectRatio: worldW / worldH,
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final scale = box.maxWidth / worldW;
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: Listener(
                              behavior: HitTestBehavior.opaque,
                              onPointerDown: (e) => world.movePaddleTo(e.localPosition.dx / scale),
                              onPointerMove: (e) => world.movePaddleTo(e.localPosition.dx / scale),
                              onPointerHover: (e) => world.movePaddleTo(e.localPosition.dx / scale),
                              onPointerUp: (_) => world.launch(),
                              child: CustomPaint(
                                painter: WorldPainter(world: world, effects: effects, theme: theme, repaint: frame),
                              ),
                            ),
                          ),
                          if (phase == Phase.playing) ...[
                            Positioned(
                              right: 0,
                              top: 0,
                              width: 44 * scale,
                              height: 44 * scale,
                              child: IconButton(
                                key: const Key('pause'),
                                onPressed: _togglePause,
                                icon: Icon(Icons.pause_rounded, color: ink, size: 22 * scale),
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: _Prompts(world: world, frame: frame, introTime: () => introTime, scale: scale),
                              ),
                            ),
                          ],
                          if (phase == Phase.paused)
                            Positioned.fill(
                              child: PauseOverlay(
                                muted: services.sound.muted,
                                onResume: _togglePause,
                                onToggleSound: () async {
                                  await services.sound.setMuted(!services.sound.muted);
                                  setState(() {});
                                },
                                onQuit: () => Navigator.of(context).pop(),
                              ),
                            ),
                          if (phase == Phase.intermission && result != null)
                            Positioned.fill(
                              child: IntermissionOverlay(result: result!, onContinue: _nextLevel),
                            ),
                          if (phase == Phase.gameOver)
                            Positioned.fill(
                              child: GameOverOverlay(
                                score: world.score,
                                best: services.progress.bestScore,
                                level: world.spec.number,
                                checkpoint: checkpointFor(world.spec.number),
                                onRetry: () => _startLevel(SavedRun(level: checkpointFor(world.spec.number), score: 0, lives: 3)),
                                onHome: () => Navigator.of(context).pop(),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Level title at the start, then "tap to launch" while the ball waits on the paddle.
class _Prompts extends StatelessWidget {
  const _Prompts({required this.world, required this.frame, required this.introTime, required this.scale});

  final GameWorld world;
  final ValueNotifier<int> frame;
  final double Function() introTime;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: frame,
      builder: (context, _, _) {
        final t = introTime();
        final introOpacity = t < 2.2 ? 1.0 : (1 - (t - 2.2) / 0.5).clamp(0.0, 1.0);
        final spec = world.spec;
        return Stack(
          children: [
            if (introOpacity > 0)
              Positioned(
                left: 0,
                right: 0,
                top: 330 * scale,
                child: Opacity(
                  opacity: introOpacity,
                  child: Column(
                    children: [
                      if (spec.isBoss) ...[
                        Text('WARNING', style: display(14 * scale, color: danger)),
                        SizedBox(height: 4 * scale),
                        Text(spec.boss!.title.toUpperCase(), style: display(24 * scale, color: danger)),
                        SizedBox(height: 6 * scale),
                        Text(
                          spec.boss!.hint,
                          style: TextStyle(color: ink, fontSize: 12 * scale),
                        ),
                      ] else ...[
                        Text('LEVEL ${spec.number}', style: display(26 * scale, color: themeFor(spec.number).accent)),
                        SizedBox(height: 4 * scale),
                        Text(
                          spec.name.toUpperCase(),
                          style: TextStyle(color: ink, fontSize: 13 * scale, letterSpacing: 4, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (world.hasStuckBall && world.state == WorldState.playing)
              Positioned(
                left: 0,
                right: 0,
                top: 520 * scale,
                child: Opacity(
                  opacity: 0.55 + 0.45 * ((t * 2) % 1 < 0.5 ? 1 : 0.4),
                  child: Text(
                    'TAP TO LAUNCH',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ink, fontSize: 13 * scale, letterSpacing: 4, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
