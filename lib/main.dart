import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'app.dart';

import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    const apiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
    const messagingSenderId = String.fromEnvironment(
      'FIREBASE_WEB_MESSAGING_SENDER_ID',
    );
    const projectId = String.fromEnvironment('FIREBASE_WEB_PROJECT_ID');
    const authDomain = String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN');
    const storageBucket = String.fromEnvironment('FIREBASE_WEB_STORAGE_BUCKET');
    if ([
      apiKey,
      appId,
      messagingSenderId,
      projectId,
      authDomain,
    ].any((value) => value.isEmpty)) {
      throw StateError(
        'Firebase Web configuration is missing. Supply the FIREBASE_WEB_* '
        'values from a registered Firebase Web app.',
      );
    }
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: authDomain,
        storageBucket: storageBucket,
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  runApp(const PikZenApp());
}
