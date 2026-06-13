import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../../core/network/sync_service.dart';
import '../../../core/database/local_db_service.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../presentation/activation_screen.dart';

class AuthController extends GetxController {
  final ApiClient _apiClient = ApiClient();

  // Controllers for text fields
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final companyController = TextEditingController(); // For registration
  final nameController = TextEditingController(); // For registration

  var isLoading = false.obs;
  var isRegisterLoading = false.obs;
  var errorMessage = ''.obs;
  var isPasswordHidden = true.obs;

  void togglePasswordVisibility() {
    isPasswordHidden.value = !isPasswordHidden.value;
  }

  Future<void> login() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      Get.snackbar(
        'تنبيه',
        'يرجى إدخال البريد الإلكتروني وكلمة المرور',
        backgroundColor: Colors.orange.withOpacity(0.9),
        colorText: Colors.white,
      );
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      final response = await _apiClient.post(
        Endpoints.login,
        {},
        data: {
          'email': emailController.text,
          'password': passwordController.text,
        },
      );

      if (response.statusCode == 200 && response.data['access_token'] != null) {
        final token = response.data['access_token'];
        final isActivated = response.data['user']['is_activated'] ?? false;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', token);
        await prefs.setBool('is_activated', isActivated);

        if (isActivated) {
          // Perform full initial sync before routing to dashboard
          if (Get.isRegistered<SyncService>()) {
            await Get.find<SyncService>().performInitialSync();
          } else {
            final syncService = Get.put(SyncService());
            await syncService.performInitialSync();
          }
          Get.offAll(() => DashboardScreen());
        } else {
          Get.offAll(() => ActivationScreen());
        }
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        errorMessage.value = 'البريد أو كلمة المرور غير صحيحة';
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        errorMessage.value =
            'لا يمكن الاتصال بالسيرفر.\nتأكد أن هاتفك السامسونج متصل بنفس شبكة الـ Wi-Fi التي عليها اللابتوب.';
      } else {
        errorMessage.value = 'خطأ شبكة: ${e.message}';
      }
      Get.snackbar(
        'فشل الدخول',
        errorMessage.value,
        backgroundColor: Colors.red.withOpacity(0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 6),
      );
    } catch (e) {
      errorMessage.value = 'خطأ غير متوقع: ${e.toString()}';
      Get.snackbar(
        'خطأ نظام',
        errorMessage.value,
        backgroundColor: Colors.red.withOpacity(0.9),
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> register() async {
    if (emailController.text.isEmpty ||
        passwordController.text.isEmpty ||
        companyController.text.isEmpty ||
        nameController.text.isEmpty) {
      Get.snackbar(
        'تنبيه',
        'يرجى تعبئة جميع الحقول',
        backgroundColor: Colors.orange.withOpacity(0.9),
        colorText: Colors.white,
      );
      return;
    }

    isRegisterLoading.value = true;
    errorMessage.value = '';

    try {
      // The endpoint is /auth/register
      final response = await _apiClient.post(
        '/auth/register',
        {},
        data: {
          'company_name': companyController.text,
          'name': nameController.text,
          'email': emailController.text,
          'password': passwordController.text,
        },
      );

      if (response.statusCode == 201 && response.data['access_token'] != null) {
        final token = response.data['access_token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', token);
        await prefs.setBool('is_activated', false); // New users are not activated

        Get.offAll(() => ActivationScreen());
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        errorMessage.value =
            'لا يمكن الاتصال بالسيرفر.\nتأكد أن هاتفك متصل بنفس شبكة الـ Wi-Fi وأن السيرفر يعمل.';
      } else if (e.response?.statusCode == 422) {
        final errors = e.response?.data['errors'];
        if (errors != null && errors.isNotEmpty) {
          errorMessage.value = errors.values.first[0].toString();
        } else {
          errorMessage.value =
              e.response?.data['message'] ?? 'بيانات غير صالحة';
        }
      } else {
        errorMessage.value = 'خطأ: ${e.response?.data['message'] ?? e.message}';
      }
      Get.snackbar(
        'فشل التسجيل',
        errorMessage.value,
        backgroundColor: Colors.red.withOpacity(0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 6),
      );
    } catch (e) {
      errorMessage.value = 'خطأ غير متوقع: ${e.toString()}';
      Get.snackbar(
        'خطأ نظام',
        errorMessage.value,
        backgroundColor: Colors.red.withOpacity(0.9),
        colorText: Colors.white,
      );
    } finally {
      isRegisterLoading.value = false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('is_activated');
    try {
      final dbService = LocalDbService.instance;
      final db = await dbService.database;
      await db.delete('customers');
      await db.delete('debts');
      await db.delete('payments');
      await db.delete('sync_queue');
    } catch (e) {
      // ignore
    }
  }

  Future<void> activateAccount(String code) async {
    if (code.isEmpty) {
      Get.snackbar('تنبيه', 'يرجى إدخال كود التفعيل', backgroundColor: Colors.orange.withOpacity(0.9), colorText: Colors.white);
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      final response = await _apiClient.post(
        '/auth/activate',
        {},
        data: {'code': code},
      );

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_activated', true);
        
        Get.snackbar(
          'نجاح',
          'تم تفعيل الحساب بنجاح! مرحباً بك.',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        
        if (Get.isRegistered<SyncService>()) {
          await Get.find<SyncService>().performInitialSync();
        } else {
          final syncService = Get.put(SyncService());
          await syncService.performInitialSync();
        }
        
        Get.offAll(() => DashboardScreen());
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        final errors = e.response?.data['errors'];
        if (errors != null && errors.isNotEmpty) {
          errorMessage.value = errors.values.first[0].toString();
        } else {
          errorMessage.value = e.response?.data['message'] ?? 'كود غير صالح';
        }
      } else {
        errorMessage.value = 'خطأ: ${e.response?.data['message'] ?? e.message}';
      }
      Get.snackbar(
        'فشل التفعيل',
        errorMessage.value,
        backgroundColor: Colors.red.withOpacity(0.9),
        colorText: Colors.white,
      );
    } catch (e) {
      errorMessage.value = 'خطأ غير متوقع';
      Get.snackbar('خطأ', errorMessage.value, backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateSettings(int? day) async {
    try {
      final response = await _apiClient.post(
        '/auth/settings',
        {},
        data: {'auto_remind_day': day},
      );
      if (response.statusCode == 200) {
        Get.snackbar(
          'نجاح',
          'تم حفظ إعدادات الرسائل التلقائية',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل حفظ الإعدادات',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<bool> forgotPassword(String email) async {
    if (email.isEmpty) {
      Get.snackbar('تنبيه', 'يرجى إدخال البريد الإلكتروني', backgroundColor: Colors.orange, colorText: Colors.white);
      return false;
    }
    
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final response = await _apiClient.post('/auth/forgot-password', {}, data: {'email': email});
      if (response.statusCode == 200) {
        Get.snackbar('نجاح', response.data['message'], backgroundColor: Colors.green, colorText: Colors.white);
        return true;
      }
    } on DioException catch (e) {
      errorMessage.value = e.response?.data['message'] ?? 'فشل طلب الاستعادة';
      Get.snackbar('خطأ', errorMessage.value, backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
    return false;
  }

}
