import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/auth_controller.dart';
import 'login_screen.dart';

class ActivationScreen extends StatelessWidget {
  ActivationScreen({Key? key}) : super(key: key);

  final AuthController _authController = Get.find<AuthController>();
  final TextEditingController _codeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () {
              _authController.logout();
              Get.offAll(() => LoginScreen());
            },
            icon: const Icon(Icons.logout, color: Colors.grey),
            label: const Text('خروج', style: TextStyle(color: Colors.grey)),
          ),
        ],
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
                  Icons.verified_user_rounded,
                  size: 80,
                  color: AppTheme.primaryColor,
                ).animate().fade(duration: 500.ms).scale(delay: 200.ms),
                
                const SizedBox(height: 24),
                
                const Text(
                  'تفعيل الحساب',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ).animate().fade(delay: 400.ms).slideY(begin: 0.2, end: 0),
                
                const SizedBox(height: 8),
                
                Text(
                  'يرجى إدخال كود التفعيل الخاص بك للبدء في استخدام النظام.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ).animate().fade(delay: 500.ms).slideY(begin: 0.2, end: 0),
                
                const SizedBox(height: 48),
                
                TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'كود التفعيل (مثال: A1B2-C3D4)',
                    prefixIcon: Icon(Icons.key),
                  ),
                  textDirection: TextDirection.ltr,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold, 
                    letterSpacing: 2
                  ),
                ).animate().fade(delay: 600.ms).slideX(begin: 0.1, end: 0),
                
                const SizedBox(height: 32),
                
                Obx(() => ElevatedButton(
                  onPressed: _authController.isLoading.value 
                      ? null 
                      : () => _authController.activateAccount(_codeController.text.trim()),
                  child: _authController.isLoading.value
                      ? const SizedBox(
                          height: 20, width: 20, 
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        )
                      : const Text('تفعيل وإكمال الدخول'),
                )).animate().fade(delay: 800.ms).scale(),
                
                const SizedBox(height: 24),
                
                const Divider(height: 32),
                
                const Text(
                  'لا تملك كود تفعيل؟',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ).animate().fade(delay: 900.ms).slideY(begin: 0.2, end: 0),
                
                const SizedBox(height: 16),
                
                OutlinedButton.icon(
                  onPressed: () => _buyCodeViaWhatsApp(),
                  icon: const Icon(Icons.shopping_cart_outlined, color: Colors.green),
                  label: const Text(
                    'انقر لشراء كود التفعيل',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.green),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ).animate().fade(delay: 1000.ms).scale(),
                
                const SizedBox(height: 8),
                
                Text(
                  '+967 775 904 988',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    letterSpacing: 1.5,
                  ),
                  textDirection: TextDirection.ltr,
                ).animate().fade(delay: 1100.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _buyCodeViaWhatsApp() async {
    const phoneNumber = '+967775904988';
    const message = 'السلام عليكم، أرغب في شراء كود تفعيل لتطبيق Taswiyah. الرجاء تزويدي بالتفاصيل الخاصة بالسعر وطريقة الدفع وآلية استلام كود التفعيل. شكرًا لكم.';
    
    final Uri whatsappUrl = Uri.parse('whatsapp://send?phone=$phoneNumber&text=${Uri.encodeComponent(message)}');
    final Uri webUrl = Uri.parse('https://wa.me/${phoneNumber.replaceAll('+', '')}?text=${Uri.encodeComponent(message)}');

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl);
      } else if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        Get.snackbar(
          'تنبيه',
          'تطبيق واتساب غير مثبت على جهازك، يرجى التواصل على الرقم: $phoneNumber',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
      }
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'لم نتمكن من فتح واتساب',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
