import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

enum Sfx {
  paddle,
  wall,
  hit,
  break1,
  break2,
  break3,
  break4,
  break5,
  steel,
  explode,
  powerup,
  bad,
  laser,
  bosshit,
  bossshoot,
  stun,
  bossdown,
  lost,
  clear,
  gameover,
}

abstract class SoundService {
  bool get muted;
  Future<void> setMuted(bool value);
  void play(Sfx sfx);

  /// Break sound for a brick's strength: tougher bricks ring higher.
  static Sfx breakFor(int maxHp) => Sfx.values[Sfx.break1.index + (maxHp.clamp(1, 5) - 1)];
}

class NoSound implements SoundService {
  @override
  bool muted = false;

  final played = <Sfx>[];

  @override
  Future<void> setMuted(bool value) async => muted = value;

  @override
  void play(Sfx sfx) {
    if (!muted) played.add(sfx);
  }
}

/// Short effects from assets/sfx (synthesized by tools/make_sfx.py), one small player pool each.
class AudioSoundService implements SoundService {
  AudioSoundService({required bool muted, required Future<void> Function(bool) persist})
    : _muted = muted, // ignore: prefer_initializing_formals
      _persist = persist; // ignore: prefer_initializing_formals

  bool _muted;
  final Future<void> Function(bool) _persist;
  final _pools = <Sfx, Future<AudioPool>>{};
  final _lastPlayed = <Sfx, DateTime>{};

  @override
  bool get muted => _muted;

  @override
  Future<void> setMuted(bool value) async {
    _muted = value;
    await _persist(value);
  }

  @override
  void play(Sfx sfx) {
    if (_muted) return;
    // A chain explosion breaks many bricks in one frame; one sound each 40 ms is plenty.
    final now = DateTime.now();
    final last = _lastPlayed[sfx];
    if (last != null && now.difference(last).inMilliseconds < 40) return;
    _lastPlayed[sfx] = now;
    final pool = _pools.putIfAbsent(sfx, () => AudioPool.createFromAsset(path: 'sfx/${sfx.name}.wav', maxPlayers: 3));
    unawaited(() async {
      try {
        await (await pool).start(volume: 0.7);
      } catch (_) {
        // Browsers can refuse audio before the first user gesture; a missed effect is fine.
      }
    }());
  }
}
