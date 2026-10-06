import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../dashboard/presentation/dashboard_screen.dart';

class BackupOnboardingScreen extends StatefulWidget {
  final VoidCallback? onFinished;

  const BackupOnboardingScreen({super.key, this.onFinished});

  static const String prefsKey = 'has_seen_backup_onboarding';

  @override
  State<BackupOnboardingScreen> createState() => _BackupOnboardingScreenState();
}

class _BackupOnboardingScreenState extends State<BackupOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<({String title, String description, IconData icon, Color color})> _slides = [
    (
      title: 'احفظ بياناتك بأمان',
      description: 'يمكنك الاحتفاظ بنسخة احتياطية من بيانات Taswiyah على Google Drive واستعادتها عند تغيير هاتفك أو حذف التطبيق.',
      icon: Icons.cloud_done_rounded,
      color: Colors.blue.shade700,
    ),
    (
      title: 'استعد بياناتك بسهولة',
      description: 'إذا غيرت هاتفك، سجل الدخول إلى Taswiyah واربط نفس حساب Google لاستعادة النسخة الاحتياطية بضغطة زر واحدة.',
      icon: Icons.restore_rounded,
      color: Colors.teal.shade700,
    ),
    (
      title: 'أنت المتحكم دائماً',
      description: 'يمكنك إنشاء نسخة احتياطية جديدة في أي وقت من الإعدادات، وبياناتك المالية مشفرة ومحفوظة ضمن مساحتك الخاصة.',
      icon: Icons.security_rounded,
      color: AppTheme.primaryColor,
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(BackupOnboardingScreen.prefsKey, true);

    if (widget.onFinished != null) {
      widget.onFinished!();
    } else {
      Get.offAll(() => DashboardScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              // Top Skip button
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: const Text('تخطي', style: TextStyle(color: Colors.grey, fontSize: 14)),
                ),
              ),

              // Page View
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: slide.color.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(slide.icon, size: 64, color: slide.color),
                          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                          const SizedBox(height: 36),
                          Text(
                            slide.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ).animate().fade().slideY(begin: 0.2, end: 0),
                          const SizedBox(height: 16),
                          Text(
                            slide.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.6,
                              color: Colors.grey.shade600,
                            ),
                          ).animate().fade(delay: 200.ms),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Page indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index ? AppTheme.primaryColor : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Bottom Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _slides.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _completeOnboarding();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _currentPage == _slides.length - 1 ? 'فهمت، ابدأ الآن' : 'التالي',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
