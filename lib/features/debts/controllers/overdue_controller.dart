import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/local_db_service.dart';
import '../../dashboard/controllers/dashboard_controller.dart';
import '../models/overdue_period.dart';

class OverdueController extends GetxController {
  final LocalDbService _dbService = LocalDbService.instance;
  static const String prefsKey = 'overdue_threshold_days';

  var isLoading = false.obs;
  var selectedDays = OverduePeriod.defaultDays.obs;
  var overdueCustomers = <Map<String, dynamic>>[].obs;
  var filteredCustomers = <Map<String, dynamic>>[].obs;
  var totalOverdueBalance = 0.0.obs;
  var searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDays = prefs.getInt(prefsKey) ?? OverduePeriod.defaultDays;
      selectedDays.value = savedDays;
    } catch (_) {
      selectedDays.value = OverduePeriod.defaultDays;
    }
    await fetchOverdueCustomers();
  }

  Future<void> setThresholdDays(int days) async {
    if (days <= 0) return;
    selectedDays.value = days;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(prefsKey, days);
    } catch (_) {}

    await fetchOverdueCustomers();

    // Synchronize with DashboardController if registered
    if (Get.isRegistered<DashboardController>()) {
      Get.find<DashboardController>().fetchStats();
    }
  }

  Future<void> fetchOverdueCustomers() async {
    isLoading.value = true;
    try {
      final list = await _dbService.getOverdueCustomers(thresholdDays: selectedDays.value);
      overdueCustomers.assignAll(list);
      _applyFilter();
    } catch (e) {
      debugPrint('Error fetching overdue customers: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void onSearchChanged(String query) {
    searchQuery.value = query.trim();
    _applyFilter();
  }

  void _applyFilter() {
    final q = searchQuery.value.toLowerCase();
    List<Map<String, dynamic>> result = overdueCustomers;
    if (q.isNotEmpty) {
      result = overdueCustomers.where((c) {
        final name = (c['name'] ?? '').toString().toLowerCase();
        final phone = (c['primary_phone'] ?? '').toString().toLowerCase();
        return name.contains(q) || phone.contains(q);
      }).toList();
    }

    filteredCustomers.assignAll(result);

    double sum = 0.0;
    for (var c in result) {
      sum += double.tryParse((c['remaining_balance'] ?? 0).toString()) ?? 0.0;
    }
    totalOverdueBalance.value = sum;
  }
}
