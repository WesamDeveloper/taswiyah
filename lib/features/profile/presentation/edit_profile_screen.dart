import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/local_db_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/controllers/dashboard_controller.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final LocalDbService _dbService = LocalDbService.instance;
  
  bool _isLoading = false;
  bool _isInitLoading = true;
  bool _isNewPasswordHidden = true;
  bool _isConfirmPasswordHidden = true;
  String _selectedAvatar = 'person';

  final List<Map<String, dynamic>> _avatars = [
    {'id': 'person', 'icon': Icons.person},
    {'id': 'store', 'icon': Icons.store},
    {'id': 'business', 'icon': Icons.business},
    {'id': 'account_circle', 'icon': Icons.account_circle},
    {'id': 'face', 'icon': Icons.face},
    {'id': 'shopping_bag', 'icon': Icons.shopping_bag},
  ];

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final profile = await _dbService.getBusinessProfile();
      final prefs = await SharedPreferences.getInstance();
      final firebaseUser = FirebaseAuth.instance.currentUser;

      final currentName = profile?['owner_name'] ?? 
                          prefs.getString('user_name') ?? 
                          firebaseUser?.displayName ?? '';
      final currentBizName = profile?['business_name'] ?? 
                             prefs.getString('company_name') ?? 'متجري';
      final currentAvatar = profile?['avatar_icon'] ?? 'person';

      _nameController.text = currentName;
      _businessNameController.text = currentBizName;
      setState(() {
        _selectedAvatar = currentAvatar;
        _isInitLoading = false;
      });
    } catch (e) {
      setState(() => _isInitLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      Get.snackbar('تنبيه', 'يرجى إدخال الاسم', backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Update Password if specified
      if (_newPasswordController.text.isNotEmpty) {
        if (_newPasswordController.text != _confirmPasswordController.text) {
          Get.snackbar('خطأ', 'كلمة المرور الجديدة وتأكيدها لا يتطابقان', backgroundColor: Colors.red, colorText: Colors.white);
          setState(() => _isLoading = false);
          return;
        }
        if (_newPasswordController.text.length < 6) {
          Get.snackbar('خطأ', 'كلمة المرور يجب أن لا تقل عن 6 أحرف', backgroundColor: Colors.red, colorText: Colors.white);
          setState(() => _isLoading = false);
          return;
        }

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await user.updatePassword(_newPasswordController.text);
        }
      }

      // 2. Update Firebase display name
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(newName);
      }

      // 3. Update local SQLite Business Profile
      final newBizName = _businessNameController.text.trim().isEmpty ? 'متجري' : _businessNameController.text.trim();
      await _dbService.saveBusinessProfile(
        businessName: newBizName,
        ownerName: newName,
        avatarIcon: _selectedAvatar,
      );

      // 4. Update SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', newName);
      await prefs.setString('company_name', newBizName);

      Get.snackbar('نجاح', 'تم حفظ وتحديث الملف الشخصي محلياً بنجاح', backgroundColor: Colors.green, colorText: Colors.white);

      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (Get.isRegistered<DashboardController>()) {
        Get.find<DashboardController>().fetchStats();
      }
    } catch (e) {
      Get.snackbar('خطأ', 'فشل حفظ التعديلات: $e', backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('تعديل الملف الشخصي', style: TextStyle(color: Colors.black87)),
        backgroundColor: AppTheme.surfaceLight,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isInitLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('اختر أيقونة الحساب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: _avatars.map((avatar) {
                      final isSelected = _selectedAvatar == avatar['id'];
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedAvatar = avatar['id'];
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryColor : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            avatar['icon'] as IconData,
                            size: 32,
                            color: isSelected ? Colors.white : Colors.grey.shade700,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),

                  TextField(
                    controller: _businessNameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم المتجر / النشاط التجاري',
                      prefixIcon: Icon(Icons.storefront_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'الاسم الكامل / المالك',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Divider(),
                  const SizedBox(height: 16),
                  const Text('تغيير كلمة المرور (اختياري)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _newPasswordController,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الجديدة',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_isNewPasswordHidden ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _isNewPasswordHidden = !_isNewPasswordHidden),
                      ),
                    ),
                    obscureText: _isNewPasswordHidden,
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'تأكيد كلمة المرور الجديدة',
                      prefixIcon: const Icon(Icons.lock_clock),
                      suffixIcon: IconButton(
                        icon: Icon(_isConfirmPasswordHidden ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _isConfirmPasswordHidden = !_isConfirmPasswordHidden),
                      ),
                    ),
                    obscureText: _isConfirmPasswordHidden,
                  ),
                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _updateProfile,
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('حفظ التعديلات'),
                  ),
                ],
              ),
            ),
    );
  }
}
