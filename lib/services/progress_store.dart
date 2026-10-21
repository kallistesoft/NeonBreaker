import 'package:shared_preferences/shared_preferences.dart';

import '../game/levels.dart';

/// A run in progress, saved at the start of every level so the player can come back to it.
class SavedRun {
  const SavedRun({required this.level, required this.score, required this.lives});

  final int level;
  final int score;
  final int lives;
}

class ProgressStore {
  ProgressStore(this._prefs);

  static Future<ProgressStore> open() async => ProgressStore(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  int get bestScore => _prefs.getInt('bestScore') ?? 0;
  int get bestLevel => _prefs.getInt('bestLevel') ?? 0;
  int get bossesBeaten => _prefs.getInt('bossesBeaten') ?? 0;
  bool get muted => _prefs.getBool('muted') ?? false;

  /// Where a new run starts: the level after the last boss ever beaten.
  int get checkpoint => _prefs.getInt('checkpoint') ?? 1;

  SavedRun? get savedRun {
    final level = _prefs.getInt('run.level');
    if (level == null) return null;
    return SavedRun(level: level, score: _prefs.getInt('run.score') ?? 0, lives: _prefs.getInt('run.lives') ?? 3);
  }

  Future<void> saveRun(SavedRun run) async {
    await _prefs.setInt('run.level', run.level);
    await _prefs.setInt('run.score', run.score);
    await _prefs.setInt('run.lives', run.lives);
    if (run.level > bestLevel) await _prefs.setInt('bestLevel', run.level);
    final cp = checkpointFor(run.level);
    if (cp > checkpoint) await _prefs.setInt('checkpoint', cp);
  }

  Future<void> clearRun() async {
    await _prefs.remove('run.level');
    await _prefs.remove('run.score');
    await _prefs.remove('run.lives');
  }

  Future<void> recordScore(int score) async {
    if (score > bestScore) await _prefs.setInt('bestScore', score);
  }

  Future<void> recordBoss() => _prefs.setInt('bossesBeaten', bossesBeaten + 1);

  Future<void> setMuted(bool value) => _prefs.setBool('muted', value);
}
