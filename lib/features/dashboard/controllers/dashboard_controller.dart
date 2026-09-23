import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/local_db_service.dart';

class DashboardController extends GetxController {
  final LocalDbService _dbService = LocalDbService.instance;
  
  var isLoading = false.obs;
  
  var userName = 'مستخدم'.obs;
  var companyName = 'متجري'.obs;
  var avatarIcon = 'person'.obs;
  
  var totalDebts = 0.0.obs;
  var totalCollected = 0.0.obs;
  var remainingBalance = 0.0.obs;
  var overdueCount = 0.obs;
  var activeCustomers = 0.obs;
  
  var chartCollections = <double>[0,0,0,0,0,0,0].obs;
  var chartDebts = <double>[0,0,0,0,0,0,0].obs;
  
  var recentActivity = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchStats();
  }

  Future<void> fetchStats() async {
    try {
      await _aggregateLocalStats();
    } catch (e) {
      debugPrint('Dashboard stats note: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadUserPreferences() async {
    try {
      // 1. Try local SQLite Business Profile first
      final profile = await _dbService.getBusinessProfile();
      if (profile != null) {
        userName.value = profile['owner_name'] ?? userName.value;
        companyName.value = profile['business_name'] ?? companyName.value;
        avatarIcon.value = profile['avatar_icon'] ?? avatarIcon.value;
      }

      // 2. Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      userName.value = prefs.getString('user_name') ?? userName.value;
      companyName.value = prefs.getString('company_name') ?? companyName.value;
    } catch (_) {}
  }

  Future<void> _aggregateLocalStats() async {
    await _loadUserPreferences();
    final allCustomers = await _dbService.getAllCustomers();
    final allDebts = await _dbService.getAllDebts();
    final allPayments = await _dbService.getAllPayments();

    double tCollected = 0;
    double rBalance = 0;
    int aCustomers = allCustomers.length;
    int oCount = 0;

    for (var c in allCustomers) {
      rBalance += double.parse((c['remaining_balance'] ?? 0).toString());
    }

    List<double> collections = List.filled(7, 0);
    List<double> debts7Days = List.filled(7, 0);

    final now = DateTime.now();
    for (var d in allDebts) {
      if (d['status'] != 'paid' && d['due_date'] != null) {
        try {
          final dueDate = DateTime.parse(d['due_date']);
          if (dueDate.isBefore(now)) oCount++;
        } catch (_) {}
      }
      
      if (d['created_at'] != null) {
        try {
          final date = DateTime.parse(d['created_at']);
          final diff = now.difference(date).inDays;
          if (diff >= 0 && diff < 7) {
            debts7Days[6 - diff] += double.parse((d['amount'] ?? 0).toString());
          }
        } catch (_) {}
      }
    }

    for (var p in allPayments) {
      tCollected += double.parse((p['amount'] ?? 0).toString());
      if (p['created_at'] != null) {
        try {
          final date = DateTime.parse(p['created_at']);
          final diff = now.difference(date).inDays;
          if (diff >= 0 && diff < 7) {
            collections[6 - diff] += double.parse((p['amount'] ?? 0).toString());
          }
        } catch (_) {}
      }
    }

    totalDebts.value = rBalance;
    totalCollected.value = tCollected;
    remainingBalance.value = rBalance;
    activeCustomers.value = aCustomers;
    overdueCount.value = oCount;
    
    chartCollections.value = collections;
    chartDebts.value = debts7Days;

    // Aggregate recent activity
    List<Map<String, dynamic>> combined = [];
    for (var d in allDebts) {
      combined.add({
        'id': d['id'],
        'type': 'debt',
        'title': 'سلفة لـ ${d['customer_name'] ?? 'عميل'}',
        'amount': double.parse((d['amount'] ?? 0).toString()),
        'created_at': d['created_at'],
      });
    }
    for (var p in allPayments) {
      combined.add({
        'id': p['id'],
        'type': 'payment',
        'title': 'تحصيل من ${p['customer_name'] ?? 'عميل'}',
        'amount': double.parse((p['amount'] ?? 0).toString()),
        'created_at': p['created_at'],
      });
    }

    combined.sort((a, b) {
      String dateA = a['created_at']?.toString() ?? '';
      String dateB = b['created_at']?.toString() ?? '';
      return dateB.compareTo(dateA); // DESC
    });

    recentActivity.value = combined.take(5).toList();
  }
}
