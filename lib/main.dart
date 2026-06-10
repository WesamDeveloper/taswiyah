import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/splash_screen.dart';

import 'core/network/sync_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Get.put(SyncService(), permanent: true);
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
