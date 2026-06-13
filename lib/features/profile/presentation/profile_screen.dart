import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/export_dialog.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../whatsapp/presentation/whatsapp_setup_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.put(AuthController());

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'حسابي والمزيد',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.surfaceLight,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CircleAvatar(
            radius: 50,
            backgroundColor: AppTheme.primaryColor,
            child: Icon(Icons.store, size: 50, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'إعدادات المتجر',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 32),

          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.person, color: Colors.purple),
              title: const Text('تعديل الملف الشخصي'),
              subtitle: const Text('تغيير الاسم، كلمة المرور، ورقم الاستعادة'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Get.to(() => const EditProfileScreen());
              },
            ),
          ),
          const SizedBox(height: 8),

          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.qr_code_scanner, color: Colors.green),
              title: const Text('ربط رقم الواتساب الخاص بك'),
              subtitle: const Text('مهم جداً لإرسال الإشعارات للعملاء'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Get.to(() => WhatsappSetupScreen());
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.schedule_send, color: Colors.blue),
              title: const Text('إرسال تذكير تلقائي للكل (شهرياً)'),
              subtitle: const Text('حدد يوم من الشهر لإرسال رسائل آلية'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _showAutoRemindDialog(context, authController);
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.orange),
              title: const Text('تصدير كشف حساب عام'),
              subtitle: const Text('استخراج تقرير لجميع العملاء (PDF/Excel)'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Get.dialog(
                  ExportDialog(
                    onExport: (format, start, end) async {
                      final exportService = Get.put(ExportService());
                      Get.snackbar(
                        'جاري التحضير',
                        'يتم الآن تجهيز كشف الحساب الشامل...',
                        backgroundColor: Colors.blue,
                        colorText: Colors.white,
                      );
                      try {
                        await exportService.exportAllCustomersStatement(
                          format: format,
                          startDate: start,
                          endDate: end,
                        );
                      } catch (e) {
                        Get.snackbar(
                          'خطأ',
                          'فشل تصدير كشف الحساب: $e',
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                        );
                      }
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.support_agent, color: Colors.teal),
              title: const Text('التواصل مع الدعم الفني'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                final uri = Uri.parse('whatsapp://send?phone=+967775904988');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else {
                  Get.snackbar('خطأ', 'تطبيق واتساب غير مثبت على جهازك.');
                }
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('تسجيل الخروج'),
              onTap: () async {
                await authController.logout();
                Get.offAllNamed('/'); // Restart from splash/login
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAutoRemindDialog(BuildContext context, AuthController controller) {
    final dayController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('رسائل التذكير التلقائية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'أدخل رقم اليوم في الشهر (مثلاً 28) ليتم إرسال رسائل تذكير لجميع العملاء آلياً. اترك الحقل فارغاً لإلغاء الميزة.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: dayController,
              decoration: const InputDecoration(labelText: 'اليوم (1 - 31)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              int? day = int.tryParse(dayController.text);
              controller.updateSettings(day);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
