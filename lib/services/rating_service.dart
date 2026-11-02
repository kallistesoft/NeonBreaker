import 'package:in_app_review/in_app_review.dart';

/// Asks players to rate the game on the store.
abstract class RatingService {
  /// True where a store exists, so the Rate button can be shown.
  bool get available;

  /// Google's in-app rating card. Google decides whether it actually appears.
  Future<void> prompt();

  /// The store page, for players who tap Rate themselves.
  Future<void> openStore();
}

/// Web and tests: no store.
class NoRatingService implements RatingService {
  const NoRatingService();

  @override
  bool get available => false;
  @override
  Future<void> prompt() async {}
  @override
  Future<void> openStore() async {}
}

class StoreRatingService implements RatingService {
  const StoreRatingService();

  @override
  bool get available => true;

  @override
  Future<void> prompt() async {
    try {
      if (await InAppReview.instance.isAvailable()) await InAppReview.instance.requestReview();
    } catch (_) {
      // Never disturb the game for a rating.
    }
  }

  @override
  Future<void> openStore() => InAppReview.instance.openStoreListing();
}
