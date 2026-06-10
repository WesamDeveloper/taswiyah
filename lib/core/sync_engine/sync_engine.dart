import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class SyncEngine {
  static final SyncEngine _instance = SyncEngine._internal();
  factory SyncEngine() => _instance;
  SyncEngine._internal();

  bool isOnline = true;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  void initialize() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      bool wasOffline = !isOnline;
      isOnline = results.isNotEmpty && results.first != ConnectivityResult.none;
      
      if (wasOffline && isOnline) {
        _triggerBackgroundSync();
      }
    });
  }

  /// Triggers when internet is restored
  Future<void> _triggerBackgroundSync() async {
    print('🌐 [SyncEngine] Network restored. Starting background sync...');
    
    try {
      // 1. Sync local pending invoices to server
      await _syncPendingInvoices();
      
      // 2. Sync local pending payments to server
      await _syncPendingPayments();
      
      // 3. Fetch latest master data from server
      await _fetchLatestData();
      
      print('✅ [SyncEngine] Background sync completed successfully.');
    } catch (e) {
      print('❌ [SyncEngine] Sync failed: $e');
    }
  }

  Future<void> _syncPendingInvoices() async {
    // 1. Query Isar Local DB: get all Invoices where syncStatus == 'pending'
    // 2. Loop through and send to Laravel API via Dio
    // 3. If successful (201 Created), update Isar record syncStatus to 'synced'
    // 4. Handle Conflicts: If Server version is newer, overwrite local (Financial Data Rule).
  }

  Future<void> _syncPendingPayments() async {
    // 1. Query Isar Local DB: get all Payments where syncStatus == 'pending'
    // 2. Push to server.
  }

  Future<void> _fetchLatestData() async {
    // Pull any changes made by other cashiers/branches from Laravel API
    // Update local Isar DB automatically
  }

  void dispose() {
    _connectivitySubscription.cancel();
  }
}
