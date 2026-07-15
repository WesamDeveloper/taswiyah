import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../controllers/auth_controller.dart';
import 'otp_verification_screen.dart';

class ForgotPasswordScreen extends StatelessWidget {
  ForgotPasswordScreen({Key? key}) : super(key: key);

  final AuthController _authController = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.lock_reset_rounded,
                  size: 80,
                  color: AppTheme.primaryColor,
                ).animate().fade(duration: 500.ms).scale(),

                const SizedBox(height: 24),

                const Text(
                  'استعادة كلمة المرور',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ).animate().fade().slideY(),

                const SizedBox(height: 16),

                Text(
                  'أدخل بريدك الإلكتروني ليتم إرسال رمز التحقق إلى رقم الواتساب المرتبط بحسابك.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ).animate().fade().slideY(),

                const SizedBox(height: 48),

                TextField(
                  controller: _authController.emailController,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                ).animate().fade().slideX(),

                const SizedBox(height: 32),

                Obx(
                  () => ElevatedButton(
                    onPressed: _authController.isLoading.value
                        ? null
                        : () async {
                            bool success = await _authController.forgotPassword(_authController.emailController.text);
                            if (success) {
                              Get.to(() => OtpVerificationScreen(email: _authController.emailController.text));
                            }
                          },
                    child: _authController.isLoading.value
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('إرسال رمز التحقق'),
                  ),
                ).animate().fade().scale(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
