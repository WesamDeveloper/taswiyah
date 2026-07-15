import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import 'reset_password_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  const OtpVerificationScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = false;

  Future<void> _verifyOtp() async {
    if (_otpController.text.length < 6) {
      Get.snackbar('تنبيه', 'يرجى إدخال الرمز المكون من 6 أرقام');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _apiClient.post('/auth/verify-otp', {}, data: {
        'email': widget.email,
        'code': _otpController.text
      });

      if (response.statusCode == 200) {
        Get.snackbar('نجاح', response.data['message'], backgroundColor: Colors.green, colorText: Colors.white);
        int resetToken = response.data['reset_token'];
        Get.off(() => ResetPasswordScreen(email: widget.email, resetToken: resetToken));
      }
    } on DioException catch (e) {
      final msg = e.response?.data['message'] ?? 'الرمز غير صحيح';
      Get.snackbar('خطأ', msg, backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      setState(() => _isLoading = false);
    }
  }

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
                  Icons.mark_email_read_rounded,
                  size: 80,
                  color: AppTheme.primaryColor,
                ).animate().fade().scale(),

                const SizedBox(height: 24),

                const Text(
                  'تحقق من الواتساب',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ).animate().fade().slideY(),

                const SizedBox(height: 16),

                Text(
                  'لقد قمنا بإرسال رمز تحقق مكون من 6 أرقام إلى حساب الواتساب الخاص بك.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ).animate().fade().slideY(),

                const SizedBox(height: 48),

                TextField(
                  controller: _otpController,
                  decoration: const InputDecoration(
                    labelText: 'رمز التحقق',
                    prefixIcon: Icon(Icons.password),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8),
                ).animate().fade().slideX(),

                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('تحقق من الرمز'),
                ).animate().fade().scale(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
