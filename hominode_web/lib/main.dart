import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'firebase_options.dart';
import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.web);

    await FirebaseAppCheck.instance.activate(
      providerWeb: ReCaptchaEnterpriseProvider(
        '6LfLtJstAAAAAFM2jk9KvFB-2f7zUr9DCNIl7HqN',
      ),
    );
  } catch (error, stackTrace) {
    debugPrint('Firebase/App Check initialization failed: $error');

    if (kDebugMode) {
      debugPrintStack(stackTrace: stackTrace);
    }

    rethrow;
  }

  runApp(const HominodeWebApp());
}
