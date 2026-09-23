import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/local_db_service.dart';
import '../../dashboard/controllers/dashboard_controller.dart';

class CustomersController extends GetxController {
  final LocalDbService _dbService = LocalDbService.instance;
  static const Uuid _uuid = Uuid();
  
  var isLoading = false.obs;
  var customers = <Map<String, dynamic>>[].obs;
  var searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchCustomers();
  }

  Future<void> fetchCustomers() async {
    try {
      await _refreshLocalList();
    } catch (e) {
      debugPrint('Customers fetch note: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _refreshLocalList() async {
    if (searchQuery.value.isEmpty) {
      customers.value = await _dbService.getAllCustomers();
    } else {
      customers.value = await _dbService.searchCustomers(searchQuery.value);
    }
  }

  void searchCustomers(String query) {
    searchQuery.value = query;
    _refreshLocalList();
  }

  Future<bool> addCustomer(String name, String phone) async {
    final cleanName = name.trim();
    final cleanPhone = phone.trim();

    // Check local duplicate
    bool exists = customers.any((c) => 
      c['name'].toString().trim().toLowerCase() == cleanName.toLowerCase() || 
      c['primary_phone'].toString().trim() == cleanPhone
    );
    
    if (exists) {
      Get.snackbar(
        'تنبيه', 
        'يوجد عميل مسجل مسبقاً بنفس الاسم أو رقم الهاتف.', 
        backgroundColor: Colors.orange, 
        colorText: Colors.white
      );
      return false;
    }

    final newId = _uuid.v4();
    final newCustomer = {
      'id': newId,
      'name': cleanName,
      'primary_phone': cleanPhone,
      'remaining_balance': 0.0,
      'notify_on_debt': 0,
      'created_at': DateTime.now().toIso8601String(),
    };

    await _dbService.saveCustomer(newCustomer);
    await _refreshLocalList();

    if (Get.isRegistered<DashboardController>()) {
      Get.find<DashboardController>().fetchStats();
    }

    Get.snackbar(
      'نجاح', 
      'تمت إضافة العميل محلياً بنجاح', 
      backgroundColor: Colors.green, 
      colorText: Colors.white
    );
    return true;
  }

  Future<void> deleteCustomer(dynamic id) async {
    final idStr = id.toString();
    await _dbService.deleteCustomer(idStr);
    await _refreshLocalList();

    if (Get.isRegistered<DashboardController>()) {
      Get.find<DashboardController>().fetchStats();
    }

    Get.snackbar(
      'نجاح', 
      'تم حذف العميل وكافة سجلاته بنجاح', 
      backgroundColor: Colors.green, 
      colorText: Colors.white,
    );
  }
}
