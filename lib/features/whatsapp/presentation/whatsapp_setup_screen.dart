import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../controllers/whatsapp_controller.dart';

class WhatsappSetupScreen extends StatelessWidget {
  WhatsappSetupScreen({Key? key}) : super(key: key);

  final WhatsappController controller = Get.put(WhatsappController());
  final TextEditingController phoneController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'إعدادات بوابة الواتساب',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.surfaceLight,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
            tooltip: 'إعادة ضبط الجلسة (إصلاح الأعطال)',
            onPressed: () {
              controller.resetSession();
              Get.snackbar(
                'تحديث',
                'جاري إعادة ضبط خادم الواتساب وتوليد جلسة جديدة...',
                backgroundColor: Colors.orange,
                colorText: Colors.white,
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Obx(() {
          if (controller.isLoading.value) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: AppTheme.primaryColor),
                const SizedBox(height: 24),
                const Text(
                  'جاري إنشاء جلسة مشفرة خاصة بمتجرك...',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            );
          }

          if (controller.isConnected.value) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 100,
                  color: AppTheme.secondaryColor,
                ).animate().scale(),
                const SizedBox(height: 24),
                const Text(
                  'تم الربط بنجاح!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryColor,
                  ),
                ).animate().fade(),
                const SizedBox(height: 12),
                const Text(
                  'نظام الإشعارات الآلي جاهز ويعمل الآن برقم متجرك.\nسيتم إرسال الفواتير والمطالبات للعملاء تلقائياً.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ],
            );
          }

          if (controller.pairingCode.value.isNotEmpty) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.phonelink_setup,
                  size: 48,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 16),
                const Text(
                  'خطوات الربط بكود التفعيل:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  '1. افتح تطبيق الواتساب بجوالك.\n2. اذهب إلى الأجهزة المرتبطة > ربط جهاز.\n3. اختر "الربط برقم هاتف بدلاً من ذلك".\n4. أدخل الكود التالي:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 15,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Text(
                    controller.pairingCode.value,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ).animate().fade().scale(),
                const SizedBox(height: 32),
                const CircularProgressIndicator(strokeWidth: 2),
                const SizedBox(height: 12),
                const Text(
                  'في انتظار إدخال الكود في هاتفك...',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            );
          }

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.chat_outlined,
                    size: 64,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'اربط رقم متجرك',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'أدخل رقم الواتساب الخاص بالمتجر (مع مفتاح الدولة، مثل: 9665xxxxxxxx أو 9677xxxxxxxx) للحصول على كود الربط.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'رقم الواتساب',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 65,
                    child: ElevatedButton(
                      onPressed: () {
                        if (phoneController.text.trim().isEmpty) {
                          Get.snackbar('تنبيه', 'يرجى إدخال رقم الهاتف أولاً');
                          return;
                        }
                        controller.requestPairingCode(
                          phoneController.text.trim(),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'احصل على كود الربط',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
