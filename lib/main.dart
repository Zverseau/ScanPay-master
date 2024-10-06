import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:scanpay/ecran_demarrage/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyAAcFfGOPe8AuYw8LrEBVAoVJiw-dLByIk",
      appId: "1:626780426776:web:0d33210ee65581627ba96d",
      messagingSenderId: "626780426776",
      projectId: "scanpay-e4242",
      storageBucket: 'scanpay-e4242.appspot.com',
    ),
  );

  await FirebaseAppCheck.instance.activate(
    webProvider:
        ReCaptchaV3Provider('6LepdQkqAAAAACN59ADb7vuCTRrqhDe3nMha9ljL'),
    androidProvider: AndroidProvider.playIntegrity,
    //appleProvider: AppleProvider.appAttest,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Splash(),
    );
  }
}
