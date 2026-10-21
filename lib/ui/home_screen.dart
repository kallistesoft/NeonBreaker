import 'package:flutter/material.dart';

import '../services/progress_store.dart';
import 'game_screen.dart';
import 'overlays.dart';
import 'palette.dart';
import 'services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _play(SavedRun run) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GameScreen(run: run)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final services = Services.of(context);
    final progress = services.progress;
    final saved = progress.savedRun;
    final checkpoint = progress.checkpoint;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0B0620), Color(0xFF2A0B3D)]),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('NEON', style: display(56, color: neonPink)),
                  Text('BREAKER', style: display(40, color: neonCyan)),
                  const SizedBox(height: 10),
                  const Text('Break the grid. Beat the bosses.', style: TextStyle(color: dim, fontSize: 14, letterSpacing: 1)),
                  const SizedBox(height: 40),
                  if (saved != null) ...[
                    NeonButton(key: const Key('continue'), label: 'CONTINUE · LEVEL ${saved.level}', onPressed: () => _play(saved)),
                    const SizedBox(height: 14),
                    NeonButton(
                      key: const Key('new'),
                      label: 'NEW RUN',
                      filled: false,
                      onPressed: () => _play(SavedRun(level: checkpoint, score: 0, lives: 3)),
                    ),
                  ] else
                    NeonButton(
                      key: const Key('play'),
                      label: checkpoint > 1 ? 'PLAY · LEVEL $checkpoint' : 'PLAY',
                      onPressed: () => _play(SavedRun(level: checkpoint, score: 0, lives: 3)),
                    ),
                  if (checkpoint > 1)
                    TextButton(
                      onPressed: () => _play(const SavedRun(level: 1, score: 0, lives: 3)),
                      child: const Text('Start over from level 1', style: TextStyle(color: dim)),
                    ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Record('BEST SCORE', '${progress.bestScore}'),
                      _Record('BEST LEVEL', '${progress.bestLevel}'),
                      _Record('BOSSES', '${progress.bossesBeaten}'),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const _HowTo(),
                  const SizedBox(height: 12),
                  IconButton(
                    tooltip: 'Sound',
                    onPressed: () async {
                      await services.sound.setMuted(!services.sound.muted);
                      setState(() {});
                    },
                    icon: Icon(services.sound.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: dim),
                  ),
                  const Text('kallistesoft.ca', style: TextStyle(color: dim, fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Record extends StatelessWidget {
  const _Record(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(color: ink, fontSize: 20, fontWeight: FontWeight.w900),
          ),
          Text(label, style: const TextStyle(color: dim, fontSize: 10, letterSpacing: 1.5)),
        ],
      ),
    );
  }
}

class _HowTo extends StatelessWidget {
  const _HowTo();

  @override
  Widget build(BuildContext context) {
    Widget chip(String letter, String text, Color color) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 14,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)),
            child: Text(
              letter,
              style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 190,
            child: Text(text, style: const TextStyle(color: ink, fontSize: 12)),
          ),
        ],
      ),
    );
    return Container(
      width: 300,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: dim.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'Clear every brick to finish a level. Every 5th level is a boss fight. Slide or move the mouse to steer, tap or press space to launch.',
            textAlign: TextAlign.center,
            style: TextStyle(color: dim, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 10),
          chip('W', 'Wide paddle', neonCyan),
          chip('M', 'Multi-ball', neonCyan),
          chip('L', 'Lasers', neonYellow),
          chip('S', 'Slow ball', neonCyan),
          chip('+', 'Extra life', neonPink),
          chip('-', 'Red capsules hurt: avoid them', danger),
        ],
      ),
    );
  }
}
