import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../services/ad_service.dart';
import '../services/premium_service.dart';
import '../services/progress_store.dart';
import '../services/rating_service.dart';
import '../services/sound_service.dart';

/// App-wide services, available to every screen.
class Services extends InheritedWidget {
  Services({
    super.key,
    required this.progress,
    required this.ads,
    required this.sound,
    PremiumService? premium,
    this.rating = const NoRatingService(),
    this.adRectangle,
    this.privacyOptionsRequired,
    this.showPrivacyOptions,
    required super.child,
  }) : premium = premium ?? NoPremiumService();

  final ProgressStore progress;
  final AdService ads;
  final SoundService sound;
  final PremiumService premium;
  final RatingService rating;

  /// The 300×250 ad on the level-clear screen; null where there are no ads (web).
  final WidgetBuilder? adRectangle;

  /// Consent controls; null where they aren't wired (web, tests).
  final ValueListenable<bool>? privacyOptionsRequired;
  final VoidCallback? showPrivacyOptions;

  static Services of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<Services>()!;

  @override
  bool updateShouldNotify(Services old) =>
      old.progress != progress || old.ads != ads || old.sound != sound || old.premium != premium || old.rating != rating;
}
