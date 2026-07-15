import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final int resetToken;
  const ResetPasswordScreen({Key? key, required this.email, required this.resetToken}) : super(key: key);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = false;
  bool _isPasswordHidden = true;

  Future<void> _resetPassword() async {
    if (_passwordController.text.length < 6) {
      Get.snackbar('تنبيه', 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _apiClient.post('/auth/reset-password', {}, data: {
        'email': widget.email,
        'reset_token': widget.resetToken,
        'password': _passwordController.text
      });

      if (response.statusCode == 200) {
        Get.snackbar('نجاح', response.data['message'], backgroundColor: Colors.green, colorText: Colors.white);
        Get.offAll(() => LoginScreen());
      }
    } on DioException catch (e) {
      final msg = e.response?.data['message'] ?? 'فشل تعيين كلمة المرور';
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
                  Icons.lock_person_rounded,
                  size: 80,
                  color: AppTheme.primaryColor,
                ).animate().fade().scale(),

                const SizedBox(height: 24),

                const Text(
                  'تعيين كلمة مرور جديدة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ).animate().fade().slideY(),

                const SizedBox(height: 16),

                Text(
                  'أدخل كلمة المرور الجديدة الخاصة بك لحماية حسابك.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ).animate().fade().slideY(),

                const SizedBox(height: 48),

                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور الجديدة',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordHidden ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordHidden = !_isPasswordHidden;
                        });
                      },
                    ),
                  ),
                  obscureText: _isPasswordHidden,
                  textDirection: TextDirection.ltr,
                ).animate().fade().slideX(),

                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _isLoading ? null : _resetPassword,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('حفظ وتسجيل الدخول'),
                ).animate().fade().scale(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
