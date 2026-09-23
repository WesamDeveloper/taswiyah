import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/local_db_service.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../presentation/activation_screen.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalDbService _dbService = LocalDbService.instance;

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

  /// Handles Firebase Authentication Login and checks Firestore License
  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      Get.snackbar(
        'تنبيه',
        'يرجى إدخال البريد الإلكتروني وكلمة المرور',
        backgroundColor: Colors.orange.withValues(alpha: 0.9),
        colorText: Colors.white,
      );
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('فشل الحصول على بيانات المستخدم');
      }

      // Check Activation / License from Firestore
      bool isActivated = false;
      String companyName = 'متجري';
      String ownerName = user.displayName ?? 'المالك';

      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          isActivated = data['isActivated'] == true || data['licenseStatus'] == 'active';
          companyName = data['companyName'] ?? companyName;
          ownerName = data['ownerName'] ?? ownerName;
        }
      } catch (e) {
        // In case of offline or Firestore read failure, check local preferences
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getString('user_uid') == user.uid && prefs.getBool('is_activated') == true) {
          isActivated = true;
        }
      }

      // Save local session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_uid', user.uid);
      await prefs.setString('user_email', user.email ?? email);
      await prefs.setString('user_name', ownerName);
      await prefs.setString('company_name', companyName);
      await prefs.setBool('is_activated', isActivated);
      await prefs.setBool('is_logged_in', true);

      // Save to local SQLite business profile
      await _dbService.saveBusinessProfile(
        businessName: companyName,
        ownerName: ownerName,
      );

      if (isActivated) {
        Get.offAll(() => DashboardScreen());
      } else {
        Get.offAll(() => ActivationScreen());
      }
    } on FirebaseAuthException catch (e) {
      errorMessage.value = _translateFirebaseAuthError(e.code);
      Get.snackbar(
        'فشل الدخول',
        errorMessage.value,
        backgroundColor: Colors.red.withValues(alpha: 0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      errorMessage.value = 'حدث خطأ: ${e.toString()}';
      Get.snackbar(
        'خطأ نظام',
        errorMessage.value,
        backgroundColor: Colors.red.withValues(alpha: 0.9),
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Handles Multi-Tenant / Business Registration via Firebase Authentication
  Future<void> register() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final companyName = companyController.text.trim();
    final ownerName = nameController.text.trim();

    if (email.isEmpty || password.isEmpty || companyName.isEmpty || ownerName.isEmpty) {
      Get.snackbar(
        'تنبيه',
        'يرجى تعبئة جميع الحقول',
        backgroundColor: Colors.orange.withValues(alpha: 0.9),
        colorText: Colors.white,
      );
      return;
    }

    isRegisterLoading.value = true;
    errorMessage.value = '';

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('فشل إنشاء الحساب');
      }

      await user.updateDisplayName(ownerName);

      // Create License / Activation document in Firestore
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'ownerName': ownerName,
          'companyName': companyName,
          'isActivated': false,
          'licenseStatus': 'inactive',
          'licenseId': null,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Note: Firestore doc creation failed: $e');
      }

      // Save local business profile in SQLite
      await _dbService.saveBusinessProfile(
        businessName: companyName,
        ownerName: ownerName,
      );

      // Cache session in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_uid', user.uid);
      await prefs.setString('user_email', email);
      await prefs.setString('user_name', ownerName);
      await prefs.setString('company_name', companyName);
      await prefs.setBool('is_activated', false);
      await prefs.setBool('is_logged_in', true);

      Get.offAll(() => ActivationScreen());
    } on FirebaseAuthException catch (e) {
      errorMessage.value = _translateFirebaseAuthError(e.code);
      Get.snackbar(
        'فشل التسجيل',
        errorMessage.value,
        backgroundColor: Colors.red.withValues(alpha: 0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      errorMessage.value = 'خطأ غير متوقع: ${e.toString()}';
      Get.snackbar(
        'خطأ نظام',
        errorMessage.value,
        backgroundColor: Colors.red.withValues(alpha: 0.9),
        colorText: Colors.white,
      );
    } finally {
      isRegisterLoading.value = false;
    }
  }

  /// Activates the user license
  Future<void> activateAccount(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) {
      Get.snackbar(
        'تنبيه',
        'يرجى إدخال كود التفعيل',
        backgroundColor: Colors.orange.withValues(alpha: 0.9),
        colorText: Colors.white,
      );
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      final user = _auth.currentUser;
      final uid = user?.uid;

      if (uid != null) {
        // Record activation in Firestore
        try {
          await _firestore.collection('users').doc(uid).set({
            'isActivated': true,
            'licenseStatus': 'active',
            'licenseId': cleanCode,
            'activatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Firestore license update note: $e');
        }
      }

      // Update local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_activated', true);
      await prefs.setString('license_id', cleanCode);

      Get.snackbar(
        'نجاح',
        'تم تفعيل الحساب بنجاح! مرحباً بك في تطبيق تسوية.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      Get.offAll(() => DashboardScreen());
    } catch (e) {
      errorMessage.value = 'فشل التفعيل: ${e.toString()}';
      Get.snackbar(
        'خطأ',
        errorMessage.value,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Firebase Password Reset
  Future<bool> forgotPassword(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      Get.snackbar(
        'تنبيه',
        'يرجى إدخال البريد الإلكتروني',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return false;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      await _auth.sendPasswordResetEmail(email: cleanEmail);
      Get.snackbar(
        'تم الإرسال بنجاح',
        'تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 6),
      );
      return true;
    } on FirebaseAuthException catch (e) {
      errorMessage.value = _translateFirebaseAuthError(e.code);
      Get.snackbar(
        'خطأ',
        errorMessage.value,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (e) {
      errorMessage.value = 'تعذر إرسال الرابط: ${e.toString()}';
      Get.snackbar(
        'خطأ',
        errorMessage.value,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  /// Sign Out: Clears session flags without deleting local customer/debt financial data
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      // ignore
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    await prefs.remove('user_uid');
  }

  String _translateFirebaseAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'لا يوجد حساب مسجل بهذا البريد الإلكتروني.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'كلمة المرور غير صحيحة أو البيانات غير مطابقة.';
      case 'email-already-in-use':
        return 'البريد الإلكتروني مستخدم بالفعل بحساب آخر.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً، يرجى اختيار كلمة مرور أقوى.';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صالحة.';
      case 'network-request-failed':
        return 'تعذر الاتصال بالشبكة. يرجى التحقق من اتصال الإنترنت.';
      case 'too-many-requests':
        return 'تم حظر المحاولات مؤقتاً لكثرة المحاولات الخاطئة. حاول لاحقاً.';
      default:
        return 'حدث خطأ أثناء العملية ($code).';
    }
  }
}
