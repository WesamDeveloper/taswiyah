import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/local_db_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/sync_service.dart';

class DashboardController extends GetxController {
  final ApiClient _apiClient = ApiClient();
  final SyncService _syncService = Get.find<SyncService>();
  
  var isLoading = true.obs;
  
  var userName = 'مستخدم'.obs;
  var companyName = 'الفرع'.obs;
  var avatarIcon = 'person'.obs;
  
  var totalDebts = 0.0.obs;
  var totalCollected = 0.0.obs;
  var remainingBalance = 0.0.obs;
  var overdueCount = 0.obs;
  var activeCustomers = 0.obs;
  
  var chartCollections = <double>[0,0,0,0,0,0,0].obs;
  var chartDebts = <double>[0,0,0,0,0,0,0].obs;
  
  var recentActivity = [].obs;

  @override
  void onInit() {
    super.onInit();
    fetchStats();
  }

  Future<void> fetchStats() async {
    isLoading.value = true;
    try {
      // Aggregate offline local data directly
      await _aggregateLocalStats();
    } catch (e) {
      Get.snackbar('تنبيه', 'تعذر جلب الإحصائيات المحلية: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userName.value = prefs.getString('user_name') ?? 'مستخدم';
      companyName.value = prefs.getString('company_name') ?? 'الفرع';
    } catch (_) {}
  }

  void _populateData(Map<String, dynamic> data) {
    userName.value = data['user_name'] ?? userName.value;
    companyName.value = data['company_name'] ?? companyName.value;
    avatarIcon.value = data['avatar_icon'] ?? 'person';
    totalDebts.value = double.parse(data['total_debts'].toString());
    totalCollected.value = double.parse(data['total_collected'].toString());
    remainingBalance.value = double.parse(data['remaining_balance'].toString());
    overdueCount.value = data['overdue_count'];
    activeCustomers.value = data['active_customers'];
    
    if (data['chart_data'] != null) {
      chartCollections.value = List<double>.from(data['chart_data']['collections'].map((e) => double.parse(e.toString())));
      chartDebts.value = List<double>.from(data['chart_data']['new_debts'].map((e) => double.parse(e.toString())));
    }
    
    if (data['recent_activity'] != null) {
      recentActivity.value = data['recent_activity'];
    }
  }

  Future<void> _aggregateLocalStats() async {
    await _loadUserPreferences();
    final dbService = LocalDbService.instance;
    final allCustomers = await dbService.getAllCustomers();
    final allDebts = await dbService.getAllDebts();
    final allPayments = await dbService.getAllPayments();

    double tDebts = 0;
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

    totalDebts.value = rBalance; // Ensure total debts matches the sum of remaining balances
    totalCollected.value = tCollected;
    remainingBalance.value = rBalance;
    activeCustomers.value = aCustomers;
    overdueCount.value = oCount;
    
    chartCollections.value = collections;
    chartDebts.value = debts7Days;
    overdueCount.value = oCount;

    // Aggregate recent activity
    List combined = [];
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
      String dateA = a['created_at'] ?? '';
      String dateB = b['created_at'] ?? '';
      return dateB.compareTo(dateA); // DESC
    });

    recentActivity.value = combined.take(5).toList();
  }
}
