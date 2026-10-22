// Firebase configuration for SafeHer.
//
// Hand-written from android/app/google-services.json (project safeher-cfb5a).
// Android and Web are configured. iOS needs its own Firebase app
// registration; add them here (or regenerate this file with
// `flutterfire configure`) before enabling Firebase on those platforms.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  /// Whether Firebase is configured for the current platform. Callers should
  /// check this before initializing so unconfigured platforms (web/iOS) keep
  /// running in local-only mode instead of crashing at startup.
  static bool get hasPlatformOptions =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.android;

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'Firebase is not configured for $defaultTargetPlatform yet. '
          'Register the app in the Firebase console and add its options here.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAcmsoaWx0z8l7s3hItDQ2jUMNu4hqhdwA',
    appId: '1:794636415951:android:921c06f0389ec4d92698ba',
    messagingSenderId: '794636415951',
    projectId: 'safeher-cfb5a',
    databaseURL: 'https://safeher-cfb5a-default-rtdb.firebaseio.com',
    storageBucket: 'safeher-cfb5a.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyACvXO8RLwlLRQznArRRap2rZHpDoL87CE',
    appId: '1:794636415951:web:3ddc3484989b4a892698ba',
    messagingSenderId: '794636415951',
    projectId: 'safeher-cfb5a',
    authDomain: 'safeher-cfb5a.firebaseapp.com',
    databaseURL: 'https://safeher-cfb5a-default-rtdb.firebaseio.com',
    storageBucket: 'safeher-cfb5a.firebasestorage.app',
  );
}
