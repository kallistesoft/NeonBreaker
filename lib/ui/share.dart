import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'share_card.dart';

/// Shares [card] as an image with its challenge text, so it shows up as a picture in chats and
/// stories. Falls back to the text alone where images can't be shared (web, or on error).
Future<void> shareCard(BuildContext context, ShareCard card) async {
  if (!kIsWeb) {
    try {
      final png = await renderShareCard(card);
      final result = await SharePlus.instance.share(
        ShareParams(
          text: card.text,
          files: [XFile.fromData(png, mimeType: 'image/png', name: 'neon-breaker-score.png')],
          fileNameOverrides: const ['neon-breaker-score.png'],
        ),
      );
      if (result.status != ShareResultStatus.unavailable) return;
    } catch (_) {
      // Fall back to the text.
    }
  }
  if (context.mounted) await shareText(context, card.text);
}

/// Opens the share sheet; falls back to the clipboard where sharing isn't available (desktop web).
Future<void> shareText(BuildContext context, String text) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final result = await SharePlus.instance.share(ShareParams(text: text));
    if (result.status != ShareResultStatus.unavailable) return;
  } catch (_) {
    // Fall through to the clipboard.
  }
  await Clipboard.setData(ClipboardData(text: text));
  messenger.showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
}
