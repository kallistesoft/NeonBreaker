import 'dart:math';

import 'package:flutter/material.dart';

import '../services/premium_service.dart';
import 'palette.dart';

/// "No ads" offer on the home screen, behind a grown-up check, plus Restore (required by Apple).
class RemoveAdsButtons extends StatelessWidget {
  const RemoveAdsButtons({super.key, required this.premium, this.random});

  final PremiumService premium;
  final Random? random;

  Future<void> _buy(BuildContext context) async {
    if (await askParent(context, random ?? Random())) await premium.buy();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: premium,
    builder: (context, _) {
      if (!premium.available) return const SizedBox.shrink();
      return Wrap(
        alignment: WrapAlignment.center,
        children: [
          TextButton.icon(
            key: const Key('removeAds'),
            onPressed: () => _buy(context),
            icon: const Icon(Icons.block_rounded, color: neonCyan),
            label: Text('No ads ${premium.price ?? ''}', style: const TextStyle(color: neonCyan)),
          ),
          TextButton(
            key: const Key('restore'),
            onPressed: premium.restore,
            child: const Text('Restore purchase', style: TextStyle(color: dim)),
          ),
        ],
      );
    },
  );
}

/// Parental gate: a multiplication a young child can't answer. True when answered correctly.
Future<bool> askParent(BuildContext context, Random random) async {
  final a = 6 + random.nextInt(4), b = 6 + random.nextInt(4);
  final controller = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ask a grown-up'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('What is $a × $b?'),
          TextField(key: const Key('parentAnswer'), controller: controller, keyboardType: TextInputType.number, autofocus: true),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          key: const Key('parentOk'),
          onPressed: () => Navigator.pop(context, int.tryParse(controller.text.trim()) == a * b),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
