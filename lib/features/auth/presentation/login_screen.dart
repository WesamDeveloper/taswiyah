import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../controllers/auth_controller.dart';
import 'register_screen.dart';

class LoginScreen extends StatelessWidget {
  LoginScreen({Key? key}) : super(key: key);

  final AuthController _authController = Get.put(AuthController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Animated Logo
                const Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 80,
                  color: AppTheme.primaryColor,
                ).animate().fade(duration: 500.ms).scale(delay: 200.ms),

                const SizedBox(height: 24),

                const Text(
                  'Taswiyah',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ).animate().fade(delay: 400.ms).slideY(begin: 0.2, end: 0),

                const SizedBox(height: 8),

                Text(
                  'النظام المالي الذكي لإدارة التحصيلات',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ).animate().fade(delay: 500.ms).slideY(begin: 0.2, end: 0),

                const SizedBox(height: 48),

                // Email Input
                TextField(
                  controller: _authController.emailController,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                ).animate().fade(delay: 600.ms).slideX(begin: 0.1, end: 0),

                const SizedBox(height: 16),

                // Password Input
                TextField(
                  controller: _authController.passwordController,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  textDirection: TextDirection.ltr,
                ).animate().fade(delay: 700.ms).slideX(begin: 0.1, end: 0),

                const SizedBox(height: 32),

                // Login Button
                Obx(
                  () => ElevatedButton(
                    onPressed: _authController.isLoading.value
                        ? null
                        : () => _authController.login(),
                    child: _authController.isLoading.value
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('تسجيل الدخول'),
                  ),
                ).animate().fade(delay: 800.ms).scale(),

                const SizedBox(height: 24),

                TextButton(
                  onPressed: () => Get.to(() => RegisterScreen()),
                  child: const Text(
                    'ليس لديك حساب؟ إنشاء حساب مجاني',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ).animate().fade(delay: 900.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
