import 'package:flutter/material.dart';

import '../game/levels.dart';
import 'palette.dart';
import 'services.dart';

/// The 300×250 ad between levels. Collapses without an ad, after "Remove Ads", and on phones
/// too narrow to show it in full.
class AdSlot extends StatelessWidget {
  const AdSlot({super.key});

  static const _minScreenWidth = 332.0; // 300 plus the panel's padding

  @override
  Widget build(BuildContext context) {
    final services = Services.of(context);
    final rectangle = services.adRectangle;
    if (rectangle == null || services.premium.isPremium || MediaQuery.sizeOf(context).width < _minScreenWidth) {
      return const SizedBox.shrink();
    }
    return Padding(padding: const EdgeInsets.only(bottom: 20), child: rectangle(context));
  }
}

class NeonButton extends StatelessWidget {
  const NeonButton({super.key, required this.label, required this.onPressed, this.color = neonCyan, this.filled = true});

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: filled ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 18)] : null,
        ),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            backgroundColor: filled ? color : Colors.transparent,
            foregroundColor: filled ? Colors.black : color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
              side: BorderSide(color: color, width: 2),
            ),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

/// Dark full-screen panel the overlays sit on.
class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: background.withValues(alpha: 0.92),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

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

class LevelResult {
  const LevelResult({required this.level, required this.score, required this.bonus, required this.bestCombo, required this.bricks});

  final int level;
  final int score;
  final int bonus;
  final int bestCombo;
  final int bricks;
}

/// Between levels: results, the ad slot, and what comes next.
class IntermissionOverlay extends StatelessWidget {
  const IntermissionOverlay({super.key, required this.result, required this.onContinue, this.onShareBoss});

  final LevelResult result;
  final VoidCallback onContinue;

  /// After a boss: dares friends to beat it too.
  final VoidCallback? onShareBoss;

  @override
  Widget build(BuildContext context) {
    final wasBoss = isBossLevel(result.level);
    final next = buildLevel(result.level + 1);
    return _Panel(
      children: [
        Text(
          wasBoss ? 'BOSS DEFEATED' : 'LEVEL ${result.level} CLEAR',
          style: display(26, color: wasBoss ? neonYellow : neonCyan),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [_Stat('SCORE', '${result.score}'), _Stat('BONUS', '+${result.bonus}'), _Stat('COMBO', 'x${result.bestCombo}')],
        ),
        const SizedBox(height: 20),
        if (wasBoss && onShareBoss != null) ...[
          NeonButton(key: const Key('shareBoss'), label: 'CHALLENGE FRIENDS', onPressed: onShareBoss, color: neonYellow, filled: false),
          const SizedBox(height: 6),
          const Text('Beat it? Dare your friends to do it too.', style: TextStyle(color: dim, fontSize: 12)),
          const SizedBox(height: 20),
        ],
        const AdSlot(),
        if (next.isBoss) ...[
          Text('WARNING', style: display(18, color: danger)),
          const SizedBox(height: 4),
          Text(
            'Boss ahead: ${next.boss!.title}',
            style: const TextStyle(color: ink, fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ] else
          Text(
            'Next: level ${next.number} · ${next.name}',
            style: const TextStyle(color: ink, fontSize: 15, fontWeight: FontWeight.w700),
          ),
        const SizedBox(height: 16),
        NeonButton(label: 'CONTINUE', onPressed: onContinue, color: next.isBoss ? danger : neonCyan),
      ],
    );
  }
}

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key, required this.muted, required this.onResume, required this.onToggleSound, required this.onQuit});

  final bool muted;
  final VoidCallback onResume;
  final VoidCallback onToggleSound;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      children: [
        Text('PAUSED', style: display(30, color: neonCyan)),
        const SizedBox(height: 28),
        NeonButton(label: 'RESUME', onPressed: onResume),
        const SizedBox(height: 14),
        NeonButton(label: muted ? 'SOUND: OFF' : 'SOUND: ON', onPressed: onToggleSound, filled: false),
        const SizedBox(height: 14),
        NeonButton(label: 'QUIT', onPressed: onQuit, color: neonPink, filled: false),
        const SizedBox(height: 12),
        const Text('Your run restarts at the beginning of this level.', style: TextStyle(color: dim, fontSize: 12)),
      ],
    );
  }
}

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({
    super.key,
    required this.score,
    required this.best,
    required this.level,
    required this.checkpoint,
    required this.onRetry,
    required this.onHome,
    required this.onShare,
    this.onRevive,
  });

  final int score;
  final int best;
  final int level;
  final int checkpoint;
  final VoidCallback onRetry;
  final VoidCallback onHome;
  final VoidCallback onShare;

  /// Set while the one rewarded revive of the run is on offer.
  final VoidCallback? onRevive;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      children: [
        Text('GAME OVER', style: display(32, color: danger)),
        const SizedBox(height: 18),
        Row(mainAxisSize: MainAxisSize.min, children: [_Stat('SCORE', '$score'), _Stat('BEST', '$best'), _Stat('LEVEL', '$level')]),
        if (score >= best && score > 0) ...[const SizedBox(height: 10), Text('NEW BEST', style: display(14, color: neonYellow))],
        const SizedBox(height: 28),
        if (onRevive != null) ...[
          NeonButton(key: const Key('revive'), label: 'WATCH AD · +1 LIFE', onPressed: onRevive, color: neonYellow),
          const SizedBox(height: 14),
        ],
        NeonButton(
          label: checkpoint > 1 ? 'RETRY FROM LEVEL $checkpoint' : 'RETRY',
          onPressed: onRetry,
          filled: onRevive == null,
        ),
        const SizedBox(height: 14),
        NeonButton(label: 'HOME', onPressed: onHome, filled: false),
        if (best > 0) ...[
          const SizedBox(height: 6),
          TextButton.icon(
            key: const Key('share'),
            onPressed: onShare,
            icon: const Icon(Icons.share_rounded, color: neonCyan, size: 18),
            label: const Text('Challenge friends', style: TextStyle(color: neonCyan)),
          ),
        ],
      ],
    );
  }
}
