import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return windows;
      default:
        return android;
    }
  }

  static const String serverClientId =
      '193637904272-tjkdmkcfveeqsafoj5d1cvrdb3seq7n0.apps.googleusercontent.com';

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDoQ7M7hAMGWB8HyPtXOIWhp3sxtYuvb94',
    appId: '1:193637904272:web:5b45ecd9ae221ed7908d15',
    messagingSenderId: '193637904272',
    projectId: 'engazz-35e60',
    authDomain: 'engazz-35e60.firebaseapp.com',
    storageBucket: 'engazz-35e60.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDoQ7M7hAMGWB8HyPtXOIWhp3sxtYuvb94',
    appId: '1:193637904272:android:5b45ecd9ae221ed7908d15',
    messagingSenderId: '193637904272',
    projectId: 'engazz-35e60',
    storageBucket: 'engazz-35e60.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDoQ7M7hAMGWB8HyPtXOIWhp3sxtYuvb94',
    appId: '1:193637904272:web:5b45ecd9ae221ed7908d15',
    messagingSenderId: '193637904272',
    projectId: 'engazz-35e60',
    authDomain: 'engazz-35e60.firebaseapp.com',
    storageBucket: 'engazz-35e60.firebasestorage.app',
  );
}
