import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';
import 'ad_service.dart';

/// Google AdMob on Android. Ads are preloaded so they show instantly.
class AdMobAdService implements AdService {
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  BannerAd? _rectangle;
  bool _rectangleLoading = false;
  bool _ready = false;

  /// True where players must be able to change their consent later (EU/UK, some US states).
  final privacyOptionsRequired = ValueNotifier(false);

  /// Asks for consent where the law requires it (EU/UK, some US states), then starts the SDK.
  /// The ad content rating and blocked categories are set in the AdMob console, so they can be tightened without
  /// an app update.
  Future<void> init() async {
    await _gatherConsent();
    privacyOptionsRequired.value = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
    if (!await ConsentInformation.instance.canRequestAds()) return;
    await MobileAds.instance.initialize();
    _ready = true;
    _loadInterstitial();
    _loadRewarded();
    _loadRectangle();
  }

  Future<void> _gatherConsent() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired((_) => done.complete()),
      (_) => done.complete(), // offline: use the consent stored from last time
    );
    return done.future;
  }

  /// Reopens the consent form so players can change their choice.
  Future<void> showPrivacyOptions() => ConsentForm.showPrivacyOptionsForm((_) {});

  void _loadInterstitial() => InterstitialAd.load(
        adUnitId: AdIds.interstitial,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) => _interstitial = ad,
          onAdFailedToLoad: (_) => _interstitial = null,
        ),
      );

  void _loadRewarded() => RewardedAd.load(
        adUnitId: AdIds.rewarded,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) => _rewarded = ad,
          onAdFailedToLoad: (_) => _rewarded = null,
        ),
      );

  /// Preloaded, so a late ad can't push Continue around under the player's finger.
  void _loadRectangle() {
    if (!_ready || _rectangleLoading || _rectangle != null) return;
    _rectangleLoading = true;
    BannerAd(
      size: AdSize.mediumRectangle,
      adUnitId: AdIds.rectangle,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _rectangleLoading = false;
          _rectangle = ad as BannerAd;
        },
        onAdFailedToLoad: (ad, _) {
          _rectangleLoading = false;
          ad.dispose();
        },
      ),
    ).load();
  }

  @override
  Future<void> showInterstitial() async {
    final ad = _interstitial;
    if (ad == null) {
      if (_ready) _loadInterstitial();
      return;
    }
    _interstitial = null;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) => closed.complete(),
      onAdFailedToShowFullScreenContent: (ad, _) => closed.complete(),
    );
    await ad.show();
    await closed.future;
    ad.dispose();
    _loadInterstitial();
  }

  @override
  bool get rewardedReady {
    if (_rewarded == null && _ready) _loadRewarded();
    return _rewarded != null;
  }

  @override
  Future<bool> showRewarded() async {
    final ad = _rewarded;
    if (ad == null) {
      if (_ready) _loadRewarded();
      return false;
    }
    _rewarded = null;
    var earned = false;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) => closed.complete(),
      onAdFailedToShowFullScreenContent: (ad, _) => closed.complete(),
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    await closed.future;
    ad.dispose();
    _loadRewarded();
    return earned;
  }

  /// 300×250 for the level-clear screen; empty when none has loaded yet.
  Widget rectangle() => _Rectangle(this);
}

class _Rectangle extends StatefulWidget {
  const _Rectangle(this.service);

  final AdMobAdService service;

  @override
  State<_Rectangle> createState() => _RectangleState();
}

class _RectangleState extends State<_Rectangle> {
  BannerAd? _ad;

  @override
  void initState() {
    super.initState();
    _ad = widget.service._rectangle;
    widget.service._rectangle = null;
    if (_ad == null) widget.service._loadRectangle();
  }

  @override
  void dispose() {
    _ad?.dispose();
    widget.service._loadRectangle();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    return SizedBox(width: 300, height: 250, child: AdWidget(ad: ad));
  }
}
