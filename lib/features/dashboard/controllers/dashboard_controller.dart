import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/sync_service.dart';

class DashboardController extends GetxController {
  final ApiClient _apiClient = ApiClient();
  final SyncService _syncService = Get.find<SyncService>();
  
  var isLoading = true.obs;
  
  var userName = 'مستخدم'.obs;
  var companyName = 'الفرع'.obs;
  
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
      // Load from cache first
      final prefs = await SharedPreferences.getInstance();
      final cachedStats = prefs.getString('dashboard_stats_cache');
      if (cachedStats != null) {
        _populateData(jsonDecode(cachedStats));
      }

      if (_syncService.isOnline.value) {
        final response = await _apiClient.get('/dashboard/stats');
        if (response.data['status'] == 'success') {
          final data = response.data['data'];
          _populateData(data);
          // Save to cache
          prefs.setString('dashboard_stats_cache', jsonEncode(data));
        }
      }
    } catch (e) {
      if (totalDebts.value == 0 && recentActivity.isEmpty) {
        Get.snackbar('تنبيه', 'لا يوجد اتصال بالإنترنت ولا بيانات محلية للإحصائيات');
      }
    } finally {
      isLoading.value = false;
    }
  }

  void _populateData(Map<String, dynamic> data) {
    userName.value = data['user_name'] ?? userName.value;
    companyName.value = data['company_name'] ?? companyName.value;
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
}
