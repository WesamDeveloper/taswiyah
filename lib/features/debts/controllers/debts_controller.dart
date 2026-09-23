import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/local_db_service.dart';
import '../../customers/controllers/customer_profile_controller.dart';
import '../../customers/controllers/customers_controller.dart';
import '../../dashboard/controllers/dashboard_controller.dart';

class DebtsController extends GetxController {
  final LocalDbService _dbService = LocalDbService.instance;
  static const Uuid _uuid = Uuid();

  var isLoading = false.obs;
  var debts = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchDebts();
  }

  Future<void> fetchDebts() async {
    try {
      await _refreshLocalList();
    } catch (e) {
      debugPrint('Debts fetch note: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _refreshLocalList() async {
    debts.value = await _dbService.getAllDebts();
  }

  Future<bool> addDebt(dynamic customerId, double amount, String notes) async {
    if (amount <= 0) {
      Get.snackbar('تنبيه', 'يجب أن يكون مبلغ الدين أكبر من الصفر');
      return false;
    }

    final String debtId = _uuid.v4();
    final localDebt = {
      'id': debtId,
      'customer_id': customerId.toString(),
      'amount': amount,
      'paid': 0.0,
      'status': 'unpaid',
      'notes': notes,
      'created_at': DateTime.now().toIso8601String(),
    };

    await _dbService.saveDebt(localDebt);
    await _refreshLocalList();

    if (Get.isRegistered<CustomersController>()) {
      Get.find<CustomersController>().fetchCustomers();
    }
    if (Get.isRegistered<CustomerProfileController>(tag: customerId.toString())) {
      Get.find<CustomerProfileController>(tag: customerId.toString()).fetchProfile();
    }
    if (Get.isRegistered<DashboardController>()) {
      Get.find<DashboardController>().fetchStats();
    }

    Get.snackbar(
      'نجاح',
      'تم تسجيل الدين محلياً بنجاح',
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );

    return true;
  }
}
