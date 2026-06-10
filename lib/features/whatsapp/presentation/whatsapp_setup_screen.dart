import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/whatsapp_controller.dart';

class WhatsappSetupScreen extends StatelessWidget {
  WhatsappSetupScreen({Key? key}) : super(key: key);

  final WhatsappController controller = Get.put(WhatsappController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('إعدادات بوابة الواتساب', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.surfaceLight,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Center(
        child: Obx(() {
          if (controller.isLoading.value) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: AppTheme.primaryColor),
                const SizedBox(height: 24),
                const Text('جاري إنشاء جلسة مشفرة خاصة بمتجرك...', style: TextStyle(fontSize: 16)),
              ],
            );
          }

          if (controller.isConnected.value) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 100, color: AppTheme.secondaryColor).animate().scale(),
                const SizedBox(height: 24),
                const Text(
                  'تم الربط بنجاح!',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
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

          if (controller.qrCode.value.isNotEmpty) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.qr_code_scanner, size: 48, color: AppTheme.primaryColor),
                const SizedBox(height: 16),
                const Text(
                  'خطوات الربط السريع:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  '1. افتح تطبيق الواتساب بجوالك.\n2. اذهب إلى الأجهزة المرتبطة.\n3. قم بمسح هذا الكود ليتم ربط متجرك.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: const Offset(0, 5))],
                  ),
                  child: QrImageView(
                    data: controller.qrCode.value,
                    version: QrVersions.auto,
                    size: 260.0,
                  ),
                ).animate().fade().scale(),
                const SizedBox(height: 32),
                const CircularProgressIndicator(strokeWidth: 2),
                const SizedBox(height: 12),
                const Text('في انتظار مسح الكود من هاتفك...', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            );
          }

          return const Text('حدث خطأ في جلب الباركود. تأكد من تشغيل خادم الواتساب.');
        }),
      ),
    );
  }
}
