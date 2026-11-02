import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/ad_service.dart';
import 'services/admob_ad_service.dart';
import 'services/crash_reporting.dart';
import 'services/premium_service.dart';
import 'services/progress_store.dart';
import 'services/rating_service.dart';
import 'services/sound_service.dart';
import 'ui/home_screen.dart';
import 'ui/palette.dart';
import 'ui/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final progress = await ProgressStore.open();
  final firstLaunch = progress.firstLaunch();

  // Real ads, the "Remove Ads" purchase and ratings on Android only; web and iOS stay ad-free.
  final mobile = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  AdService ads = const NoAdService();
  PremiumService premium = NoPremiumService();
  RatingService rating = const NoRatingService();
  WidgetBuilder? adRectangle;
  ValueListenable<bool>? privacyOptionsRequired;
  VoidCallback? showPrivacyOptions;
  if (mobile) {
    try {
      await initCrashReporting();
    } catch (_) {
      // Never block the game because Firebase couldn't start.
    }
    final admob = AdMobAdService();
    final store = StorePremiumService(progress);
    premium = store;
    rating = const StoreRatingService();
    ads = PremiumAwareAdService(FrequencyCappedAdService(admob, firstLaunch: firstLaunch), () => store.isPremium);
    adRectangle = (_) => admob.rectangle();
    privacyOptionsRequired = admob.privacyOptionsRequired;
    showPrivacyOptions = admob.showPrivacyOptions;
    admob.init();
    store.init();
  }

  runApp(
    NeonBreakerApp(
      progress: progress,
      ads: ads,
      premium: premium,
      rating: rating,
      adRectangle: adRectangle,
      privacyOptionsRequired: privacyOptionsRequired,
      showPrivacyOptions: showPrivacyOptions,
      sound: AudioSoundService(muted: progress.muted, persist: progress.setMuted),
    ),
  );
}

class NeonBreakerApp extends StatelessWidget {
  const NeonBreakerApp({
    super.key,
    required this.progress,
    required this.ads,
    required this.sound,
    this.premium,
    this.rating = const NoRatingService(),
    this.adRectangle,
    this.privacyOptionsRequired,
    this.showPrivacyOptions,
  });

  final ProgressStore progress;
  final AdService ads;
  final SoundService sound;
  final PremiumService? premium;
  final RatingService rating;
  final WidgetBuilder? adRectangle;
  final ValueListenable<bool>? privacyOptionsRequired;
  final VoidCallback? showPrivacyOptions;

  @override
  Widget build(BuildContext context) {
    return Services(
      progress: progress,
      ads: ads,
      sound: sound,
      premium: premium,
      rating: rating,
      adRectangle: adRectangle,
      privacyOptionsRequired: privacyOptionsRequired,
      showPrivacyOptions: showPrivacyOptions,
      child: MaterialApp(
        title: 'Brick Shatter: Neon Breaker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, brightness: Brightness.dark, colorSchemeSeed: neonCyan, scaffoldBackgroundColor: background),
        home: const HomeScreen(),
      ),
    );
  }
}
