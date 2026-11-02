/// Ad placements. Screens only use this interface, so the AdMob (mobile) and
/// portal SDK (web) implementations can be swapped in without touching gameplay.
abstract class AdService {
  /// Full-screen ad between levels, shown when the player leaves the intermission screen.
  /// Implementations enforce their own frequency cap.
  Future<void> showInterstitial();

  /// True when a rewarded video can play right now, so the offer is never a dead button.
  bool get rewardedReady;

  /// Rewarded video; returns true if the player earned the reward.
  Future<bool> showRewarded();
}

/// Web and development stand-in: no ads, so no rewarded offer either.
class NoAdService implements AdService {
  const NoAdService();

  @override
  Future<void> showInterstitial() async {}

  @override
  bool get rewardedReady => false;

  @override
  Future<bool> showRewarded() async => false;
}

/// Keeps interstitials rare: none in a new player's first minutes, then at most one per [gap].
/// Rewarded ads are opt-in, so they pass through.
class FrequencyCappedAdService implements AdService {
  FrequencyCappedAdService(
    this._inner, {
    required this.firstLaunch,
    this.clock = DateTime.now,
    this.grace = const Duration(minutes: 3),
    this.gap = const Duration(seconds: 90),
  });

  final AdService _inner;
  final DateTime firstLaunch;
  final DateTime Function() clock;
  final Duration grace;
  final Duration gap;
  DateTime? _last;

  @override
  Future<void> showInterstitial() async {
    final now = clock();
    if (now.difference(firstLaunch) < grace) return;
    if (_last != null && now.difference(_last!) < gap) return;
    _last = now;
    await _inner.showInterstitial();
  }

  @override
  bool get rewardedReady => _inner.rewardedReady;

  @override
  Future<bool> showRewarded() => _inner.showRewarded();
}

/// "Remove Ads" owners get no interstitials; the rewarded Continue stays available.
class PremiumAwareAdService implements AdService {
  const PremiumAwareAdService(this._inner, this._isPremium);

  final AdService _inner;
  final bool Function() _isPremium;

  @override
  Future<void> showInterstitial() async {
    if (!_isPremium()) await _inner.showInterstitial();
  }

  @override
  bool get rewardedReady => _inner.rewardedReady;

  @override
  Future<bool> showRewarded() => _inner.showRewarded();
}
