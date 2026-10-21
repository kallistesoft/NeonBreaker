/// Ad placements. Screens only use this interface, so the AdMob (mobile) and
/// portal SDK (web) implementations can be swapped in without touching gameplay.
abstract class AdService {
  /// Full-screen ad between levels, shown when the player leaves the intermission screen.
  /// Implementations enforce their own frequency cap.
  Future<void> showInterstitial();
}

/// Development stand-in: no ads. The intermission screen still reserves the ad slot.
class NoAdService implements AdService {
  const NoAdService();

  @override
  Future<void> showInterstitial() async {}
}
