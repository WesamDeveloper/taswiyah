import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import 'activation_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 2));
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final isActivated = prefs.getBool('is_activated') ?? false;

    if (token != null && token.isNotEmpty) {
      if (isActivated) {
        Get.offAll(() => DashboardScreen());
      } else {
        Get.offAll(() => ActivationScreen());
      }
    } else {
      Get.offAll(() => LoginScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', width: 140, height: 140)
                .animate()
                .fade(duration: 800.ms)
                .scale(curve: Curves.easeOutBack, duration: 800.ms),

            const SizedBox(height: 32),

            const Text(
                  'Taswiyah',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                )
                .animate()
                .fade(delay: 400.ms, duration: 600.ms)
                .slideY(begin: 0.2, end: 0),

            const SizedBox(height: 8),

            Text(
                  'نظام إدارة التحصيلات والديون',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                )
                .animate()
                .fade(delay: 600.ms, duration: 600.ms)
                .slideY(begin: 0.2, end: 0),

            const SizedBox(height: 48),

            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
                strokeWidth: 3,
              ),
            ).animate().fade(delay: 800.ms),
          ],
        ),
      ),
    );
  }
}
