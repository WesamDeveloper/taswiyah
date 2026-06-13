import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/sync_service.dart';
import '../../../core/database/local_db_service.dart';

class DebtsController extends GetxController {
  final ApiClient _apiClient = ApiClient();
  final SyncService _syncService = Get.find<SyncService>();
  final LocalDbService _dbService = LocalDbService.instance;

  var isLoading = true.obs;
  var debts = [].obs;

  @override
  void onInit() {
    super.onInit();
    fetchDebts();
  }

  Future<void> fetchDebts() async {
    isLoading.value = true;
    try {
      await _refreshLocalList();
    } catch (e) {
      if (debts.isEmpty) {
        Get.snackbar('تنبيه', 'يوجد مشكلة في قراءة الديون المحلية.');
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _refreshLocalList() async {
    debts.value = await _dbService.getAllDebts();
  }

  Future<bool> addDebt(int customerId, double amount, String notes) async {
    final tempId = DateTime.now().millisecondsSinceEpoch;
    final payload = {'customer_id': customerId, 'amount': amount, 'notes': notes, 'temp_id': tempId};
    
    // Save locally first
    final localDebt = {
      'id': tempId,
      'customer_id': customerId,
      'amount': amount,
      'paid': 0.0,
      'status': 'unpaid',
      'notes': notes,
      'created_at': DateTime.now().toIso8601String(),
    };
    await _dbService.saveDebt(localDebt, isSynced: false);
    debts.value = await _dbService.getAllDebts();

    bool success = await _syncService.executeOrQueue(
      'add_debt',
      payload,
    );

    if (success) {
      Get.snackbar('نجاح', 'تم تسجيل الدين وإشعار العميل', backgroundColor: Colors.green, colorText: Colors.white);
    }
    return true;
  }
}
