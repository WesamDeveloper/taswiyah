import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import 'core/network/sync_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Get.put(SyncService(), permanent: true);
  await Firebase.initializeApp();
  print(Firebase.app().options.projectId);
  print(Firebase.app().options.appId);
  print(Firebase.app().options.apiKey);
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  runApp(const TaswiyahApp());
}

class TaswiyahApp extends StatelessWidget {
  const TaswiyahApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Taswiyah',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,

      // Arabic RTL Configuration
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', 'SA'), // Arabic
        Locale('en', 'US'), // English
      ],
      locale: const Locale('ar', 'SA'),

      home: const SplashScreen(),
    );
  }
}
