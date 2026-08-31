import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaEnterpriseProvider(
      '6LfLtJstAAAAAFM2jk9KvFB-2f7zUr9DCNIl7HqN',
    ),
  );
  runApp(const HominodeWebApp());
}
