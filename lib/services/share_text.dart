import 'package:flutter/foundation.dart';

/// Added to every shared score so friends can install the game in one tap (or play it, on web).
const playStoreUrl = 'https://play.google.com/store/apps/details?id=ca.kallistesoft.neon_breaker';
const webUrl = 'https://breaker.kallistesoft.ca';

/// The hashtag every shared score carries, so challenges can be found and reposted.
const challengeTag = '#NeonBreakerChallenge';

/// Groups thousands: `18,240`.
String formatScore(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',');

/// Text players paste into chats and social posts: their best score as a dare.
String bestScoreShareText({required int score, required int level}) => [
      'My best in Brick Shatter: Neon Breaker 🧱',
      '🏆 ${formatScore(score)} points${level > 1 ? ' · level $level' : ''}',
      'Can you beat it? 👀 $challengeTag',
      if (kIsWeb) webUrl else playStoreUrl,
    ].join('\n');

/// Shared right after a boss falls, while the player is proudest: "I beat it, did you?".
String bossShareText({required String boss, required int score, required int level}) => [
      'I just beat $boss in Brick Shatter: Neon Breaker! 💥',
      '🏆 ${formatScore(score)} points · level $level',
      'Did you? 👀 $challengeTag',
      if (kIsWeb) webUrl else playStoreUrl,
    ].join('\n');
