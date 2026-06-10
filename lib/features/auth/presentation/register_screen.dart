import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/auth_controller.dart';
import 'login_screen.dart';

class RegisterScreen extends StatelessWidget {
  RegisterScreen({Key? key}) : super(key: key);

  // Fetch the existing controller instance
  final AuthController _authController = Get.find<AuthController>();

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
                const Icon(
                  Icons.business,
                  size: 80,
                  color: AppTheme.primaryColor,
                ).animate().fade().scale(),
                
                const SizedBox(height: 24),
                
                const Text(
                  'إنشاء حساب جديد',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
                ).animate().fade().slideY(),
                
                const SizedBox(height: 48),
                
                // Company Name
                TextField(
                  controller: _authController.companyController,
                  decoration: const InputDecoration(labelText: 'اسم الشركة / المتجر', prefixIcon: Icon(Icons.store)),
                ).animate().fade().slideX(),
                
                const SizedBox(height: 16),
                
                // Full Name
                TextField(
                  controller: _authController.nameController,
                  decoration: const InputDecoration(labelText: 'اسم المالك (أنت)', prefixIcon: Icon(Icons.person)),
                ).animate().fade().slideX(),
                
                const SizedBox(height: 16),
                
                // Email
                TextField(
                  controller: _authController.emailController,
                  decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email)),
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                ).animate().fade().slideX(),
                
                const SizedBox(height: 16),
                
                // Password
                TextField(
                  controller: _authController.passwordController,
                  decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.lock)),
                  obscureText: true,
                  textDirection: TextDirection.ltr,
                ).animate().fade().slideX(),
                
                const SizedBox(height: 32),
                
                // Register Button
                Obx(() => ElevatedButton(
                  onPressed: _authController.isRegisterLoading.value 
                      ? null 
                      : () => _authController.register(),
                  child: _authController.isRegisterLoading.value
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('تسجيل وفتح النظام'),
                )).animate().fade().scale(),
                
                const SizedBox(height: 24),
                
                // Back to login
                TextButton(
                  onPressed: () => Get.to(() => LoginScreen()),
                  child: const Text('لديك حساب بالفعل؟ تسجيل الدخول', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                ).animate().fade(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
