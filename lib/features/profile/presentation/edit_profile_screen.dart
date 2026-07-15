import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../auth/presentation/forgot_password_screen.dart';
import '../../dashboard/controllers/dashboard_controller.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = false;
  bool _isInitLoading = true;
  bool _isCurrentPasswordHidden = true;
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
      final response = await _apiClient.get('/auth/me');
      if (response.statusCode == 200) {
        final data = response.data['data'];
        _nameController.text = data['name'] ?? '';
        setState(() {
          _selectedAvatar = data['avatar_icon'] ?? 'person';
          _isInitLoading = false;
        });
      }
    } catch (e) {
      Get.snackbar('خطأ', 'فشل جلب بيانات الملف الشخصي');
      setState(() {
        _isInitLoading = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> data = {
        'name': _nameController.text,
        'avatar_icon': _selectedAvatar,
      };

      if (_newPasswordController.text.isNotEmpty) {
        if (_newPasswordController.text != _confirmPasswordController.text) {
          Get.snackbar('خطأ', 'كلمة المرور الجديدة وتأكيدها لا يتطابقان', backgroundColor: Colors.red, colorText: Colors.white);
          setState(() => _isLoading = false);
          return;
        }
        if (_currentPasswordController.text.isEmpty) {
          Get.snackbar('خطأ', 'يرجى إدخال كلمة المرور الحالية', backgroundColor: Colors.red, colorText: Colors.white);
          setState(() => _isLoading = false);
          return;
        }
        data['password'] = _newPasswordController.text;
        data['current_password'] = _currentPasswordController.text;
      }

      final response = await _apiClient.post('/auth/profile', {}, data: data);
      
      if (response.statusCode == 200) {
        Get.snackbar('نجاح', 'تم تحديث الملف الشخصي بنجاح', backgroundColor: Colors.green, colorText: Colors.white);
        
        // Clear passwords after success
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        
        // Wait a bit to ensure snackbar shows, then maybe refresh dashboard
        Future.delayed(const Duration(seconds: 1), () {
           if (Get.isRegistered<DashboardController>()) {
             Get.find<DashboardController>().fetchStats();
           }
        });
      }
    } on DioException catch (e) {
      final msg = e.response?.data['message'] ?? 'فشل التحديث';
      Get.snackbar('خطأ', msg, backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  IconData _getIconData(String id) {
    return _avatars.firstWhere((element) => element['id'] == id, orElse: () => _avatars[0])['icon'];
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
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedAvatar = avatar['id'];
                          });
                        },
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
                          child: Icon(avatar['icon'], size: 30, color: isSelected ? Colors.white : Colors.grey.shade700),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'الاسم / اسم المتجر', prefixIcon: Icon(Icons.person)),
                  ),
                  
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text('تغيير كلمة المرور', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _currentPasswordController,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الحالية',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_isCurrentPasswordHidden ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _isCurrentPasswordHidden = !_isCurrentPasswordHidden),
                      ),
                    ),
                    obscureText: _isCurrentPasswordHidden,
                    textDirection: TextDirection.ltr,
                  ),
                  
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        Get.to(() => ForgotPasswordScreen());
                      },
                      child: const Text('نسيت كلمة المرور؟', style: TextStyle(color: AppTheme.primaryColor)),
                    ),
                  ),
                  
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
                    textDirection: TextDirection.ltr,
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'تأكيد كلمة المرور الجديدة',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_isConfirmPasswordHidden ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _isConfirmPasswordHidden = !_isConfirmPasswordHidden),
                      ),
                    ),
                    obscureText: _isConfirmPasswordHidden,
                    textDirection: TextDirection.ltr,
                  ),

                  const SizedBox(height: 48),
                  
                  ElevatedButton(
                    onPressed: _isLoading ? null : _updateProfile,
                    child: _isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('حفظ التعديلات', style: TextStyle(color: Colors.white, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
