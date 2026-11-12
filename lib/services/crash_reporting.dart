import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Starts Firebase and sends uncaught errors to Crashlytics (project brick-shatter).
/// Collection is off in debug builds so test crashes don't mix with players' reports.
Future<void> initCrashReporting() async {
  await Firebase.initializeApp();
  final crashlytics = FirebaseCrashlytics.instance;
  await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode || _crashTest);
  FlutterError.onError = crashlytics.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    // A failed sound effect doesn't stop the game; keep it out of the crash-free numbers.
    final audio = error is PlatformException && error.code == 'AndroidAudioError';
    crashlytics.recordError(error, stack, fatal: !audio);
    return true;
  };
  if (_crashTest) {
    Future.delayed(const Duration(seconds: 8), () => throw StateError('Crashlytics test crash'));
  }
}

/// `--dart-define=CRASH_TEST=true` makes a build crash 8 s after launch, to check reports arrive.
const _crashTest = bool.fromEnvironment('CRASH_TEST');
