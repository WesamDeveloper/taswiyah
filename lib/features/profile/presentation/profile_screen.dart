import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/database/local_db_service.dart';
import '../../../core/services/export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/export_dialog.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/presentation/login_screen.dart';
import 'edit_profile_screen.dart';

typedef SettingsScreen = ProfileScreen;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final LocalDbService _dbService = LocalDbService.instance;
  late final AuthController _authController;

  String _businessName = 'متجري';
  String _ownerName = 'مدير المتجر';
  String _avatarIcon = 'store';
  String _currency = 'ر.ي';
  int _customerCount = 0;
  int _totalTransactionsCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _authController = Get.put(AuthController());
    _loadProfileAndTelemetry();
  }

  Future<void> _loadProfileAndTelemetry() async {
    try {
      final profile = await _dbService.getBusinessProfile();
      final prefs = await SharedPreferences.getInstance();
      final allCust = await _dbService.getAllCustomers();
      final allDebts = await _dbService.getAllDebts();
      final allPayments = await _dbService.getAllPayments();

      if (mounted) {
        setState(() {
          _businessName = profile?['business_name'] ?? 
                          prefs.getString('company_name') ?? 
                          'متجري';
          _ownerName = profile?['owner_name'] ?? 
                       prefs.getString('user_name') ?? 
                       'مدير المتجر';
          _avatarIcon = profile?['avatar_icon'] ?? 'store';
          _currency = profile?['currency'] ?? 'ر.ي';
          _customerCount = allCust.length;
          _totalTransactionsCount = allDebts.length + allPayments.length;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  IconData _getAvatarIcon(String iconKey) {
    switch (iconKey) {
      case 'store':
        return Icons.storefront_rounded;
      case 'business':
        return Icons.business_center_rounded;
      case 'account_circle':
        return Icons.account_circle_rounded;
      case 'face':
        return Icons.face_rounded;
      case 'shopping_bag':
        return Icons.shopping_bag_rounded;
      case 'person':
      default:
        return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'الإعدادات',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppTheme.surfaceLight,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryColor),
            tooltip: 'تعديل الملف',
            onPressed: () async {
              await Get.to(() => const EditProfileScreen());
              _loadProfileAndTelemetry();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : RefreshIndicator(
              onRefresh: _loadProfileAndTelemetry,
              color: AppTheme.primaryColor,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // 1. Hero Store Profile Card
                  _buildStoreHeroCard(),

                  const SizedBox(height: 8),

                  // 2. Section: Store & Profile
                  _buildSectionHeader('إدارة المتجر والملف', Icons.storefront_outlined),
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        _buildSettingTile(
                          icon: Icons.person_outline_rounded,
                          iconColor: Colors.blue.shade700,
                          iconBgColor: Colors.blue.shade50,
                          title: 'الملف الشخصي والمتجر',
                          subtitle: 'تعديل اسم المالك، اسم المتجر، وأيقونة الحساب',
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                          onTap: () async {
                            await Get.to(() => const EditProfileScreen());
                            _loadProfileAndTelemetry();
                          },
                        ),
                        _buildDivider(),
                        _buildSettingTile(
                          icon: Icons.monetization_on_outlined,
                          iconColor: Colors.teal.shade700,
                          iconBgColor: Colors.teal.shade50,
                          title: 'العملة والتنسيق المالي',
                          subtitle: 'العملة المعتمدة في الحسابات والمعاملات',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.teal.shade200),
                            ),
                            child: Text(
                              _currency,
                              style: TextStyle(
                                color: Colors.teal.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3. Section: Reports & Local Data
                  _buildSectionHeader('التقارير وقاعدة البيانات', Icons.insights_outlined),
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        _buildSettingTile(
                          icon: Icons.description_outlined,
                          iconColor: Colors.orange.shade700,
                          iconBgColor: Colors.orange.shade50,
                          title: 'تصدير كشف حساب عام',
                          subtitle: 'استخراج تقرير شامل لجميع العملاء (PDF / Excel)',
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                          onTap: _showExportDialog,
                        ),
                        _buildDivider(),
                        _buildSettingTile(
                          icon: Icons.storage_rounded,
                          iconColor: Colors.indigo.shade700,
                          iconBgColor: Colors.indigo.shade50,
                          title: 'قاعدة البيانات المحلية (SQLite)',
                          subtitle: '$_customerCount عميل • $_totalTransactionsCount عملية محفوظة محلياً',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'SQLite نشط',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green.shade800,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 4. Section: Support & Info
                  _buildSectionHeader('الدعم ومعلومات التطبيق', Icons.help_outline_rounded),
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        _buildSettingTile(
                          icon: Icons.headset_mic_outlined,
                          iconColor: Colors.green.shade700,
                          iconBgColor: Colors.green.shade50,
                          title: 'الدعم الفني المباشر',
                          subtitle: 'مساعدة فورية واستفسارات عبر الواتساب',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'واتساب',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          onTap: _contactSupport,
                        ),
                        _buildDivider(),
                        _buildSettingTile(
                          icon: Icons.info_outline_rounded,
                          iconColor: Colors.purple.shade700,
                          iconBgColor: Colors.purple.shade50,
                          title: 'حول تطبيق تسوية',
                          subtitle: 'الإصدار v1.0.0 (Local-First Edition)',
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                          onTap: _showAboutDialog,
                        ),
                      ],
                    ),
                  ),

                  // 5. Section: Security & Logout
                  _buildSectionHeader('الأمان والحساب', Icons.shield_outlined),
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: _buildSettingTile(
                      icon: Icons.logout_rounded,
                      iconColor: Colors.red.shade700,
                      iconBgColor: Colors.red.shade50,
                      title: 'تسجيل الخروج',
                      subtitle: 'الخروج بأمان مع بقاء كافة بياناتك محفوظة على الهاتف',
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                      onTap: _showLogoutConfirmation,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Bottom App Branding Note
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'تطبيق تسوية — Taswiyah',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'نظام محاسبي لإدارة الديون • يعمل محلياً دون إنترنت',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  // ==========================================
  // --- Hero Store Profile Card ---
  // ==========================================
  Widget _buildStoreHeroCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.82),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _getAvatarIcon(_avatarIcon),
                  size: 34,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _businessName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          size: 15,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _ownerName,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_user_rounded,
                            size: 13,
                            color: Colors.greenAccent,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'نظام محلي آمن 100% • دون خادم',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Get.to(() => const EditProfileScreen());
                _loadProfileAndTelemetry();
              },
              icon: const Icon(
                Icons.edit_outlined,
                size: 16,
                color: AppTheme.primaryColor,
              ),
              label: const Text(
                'تعديل بيانات المتجر والملف الشخصي',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // --- Section Header & Tile Builders ---
  // ==========================================
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 8, top: 18),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 68,
      color: Colors.grey.shade100,
    );
  }

  // ==========================================
  // --- Dialogs & Action Handlers ---
  // ==========================================
  void _showExportDialog() {
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
  }

  Future<void> _contactSupport() async {
    final uri = Uri.parse('whatsapp://send?phone=+967775904988');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        Get.snackbar(
          'تنبيه',
          'تطبيق واتساب غير مثبت على جهازك.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'تعذر فتح الواتساب: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _showAboutDialog() {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.info_rounded, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 10),
            const Text('حول تطبيق تسوية'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تسوية — Taswiyah',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'الإصدار 1.0.0 (Local-First Standalone)',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            const Text(
              'نظام متكامل لإدارة ديون وحسابات العملاء والتحصيلات المالية وفق مبدأ FIFO.\n\n'
              'التطبيق يعمل محلياً بالكامل (Offline-First) ويحفظ كافة بياناتك بأمان تام على ذاكرة هاتفك دون إرسالها إلى أي خادم خارجي.',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.code_rounded, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    'تطوير: المهندس وسام (Wesam Developer)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Get.back(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('إغلاق', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation() {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('تسجيل الخروج', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('هل أنت متأكد من رغبتك في تسجيل الخروج من التطبيق؟'),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'بياناتك المحلية (العملاء والديون) تظل محفوظة بأمان على هاتفك.',
                    style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await _authController.logout();
              Get.offAll(() => LoginScreen());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('تأكيد الخروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
