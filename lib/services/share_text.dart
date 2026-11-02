import 'package:flutter/foundation.dart';

/// Added to every shared score so friends can install the game in one tap (or play it, on web).
const playStoreUrl = 'https://play.google.com/store/apps/details?id=ca.kallistesoft.neon_breaker';
const webUrl = 'https://breaker.kallistesoft.ca';

/// Groups thousands: `18,240`.
String formatScore(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',');

/// Text players paste into chats and social posts.
String bestScoreShareText({required int score, required int level}) => [
      'Brick Shatter: Neon Breaker 🧱',
      '🏆 Best score: ${formatScore(score)}',
      if (level > 1) '⚡ Reached level $level',
      if (kIsWeb) webUrl else playStoreUrl,
    ].join('\n');
