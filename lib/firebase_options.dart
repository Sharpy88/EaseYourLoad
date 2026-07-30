// Firebase configuration for the easeyourminddatabase-ca0de project.
//
// Android and iOS are configured. Web is still a placeholder: an empty apiKey
// keeps that platform in local-only mode with sharing disabled. Run
// `flutterfire configure` (see FIREBASE_SETUP.md) to fill it in.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCcy7DL4z5kldMDs4R8LCPSpO4oRS7vP0Y',
    appId: '1:61890354817:android:19403e60b630939d5df780',
    messagingSenderId: '61890354817',
    projectId: 'easeyourminddatabase-ca0de',
    storageBucket: 'easeyourminddatabase-ca0de.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDt4da78WWyJgL3tDpCu_gg96vJgYZo4do',
    appId: '1:61890354817:ios:34634537275918bd5df780',
    messagingSenderId: '61890354817',
    projectId: 'easeyourminddatabase-ca0de',
    storageBucket: 'easeyourminddatabase-ca0de.firebasestorage.app',
    iosBundleId: 'com.easeyourmind.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: '',
    appId: '',
    messagingSenderId: '',
    projectId: '',
  );
}
