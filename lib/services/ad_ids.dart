import 'package:flutter/foundation.dart';

/// AdMob ad unit IDs (Android). Debug builds use Google's test units so we never click our own ads.
class AdIds {
  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const _testRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const _testBanner = 'ca-app-pub-3940256099942544/6300978111';

  static const _interstitial = 'ca-app-pub-7557144664039757/6669870534';
  static const _rewarded = 'ca-app-pub-7557144664039757/6967373108';
  static const _rectangle = 'ca-app-pub-7557144664039757/6310777889';

  static String get interstitial => kReleaseMode ? _interstitial : _testInterstitial;
  static String get rewarded => kReleaseMode ? _rewarded : _testRewarded;
  static String get rectangle => kReleaseMode ? _rectangle : _testBanner;
}
