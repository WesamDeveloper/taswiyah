import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/network/api_client.dart';

class WhatsappController extends GetxController {
  final ApiClient _apiClient = ApiClient();

  var isLoading = true.obs;
  var isConnected = false.obs;
  var qrCode = ''.obs;

  Timer? _statusTimer;

  @override
  void onInit() {
    super.onInit();
    initSession();
  }

  @override
  void onClose() {
    _statusTimer?.cancel();
    super.onClose();
  }

  Future<void> resetSession() async {
    isLoading.value = true;
    _statusTimer?.cancel();
    try {
      await _apiClient.post('/whatsapp/reset', {});
      qrCode.value = '';
      isConnected.value = false;
      // Wait a moment before requesting a new session
      await Future.delayed(const Duration(seconds: 2));
      initSession();
    } catch (e) {
      isLoading.value = false;
      Get.snackbar('خطأ', 'فشل إعادة ضبط جلسة الواتساب');
    }
  }

  Future<void> initSession() async {
    isLoading.value = true;
    try {
      final response = await _apiClient.get('/whatsapp/qr');

      if (response.data['error'] != null) {
        isLoading.value = false;
        Get.snackbar(
          'خطأ',
          'خادم الواتساب غير متصل حالياً',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      } else if (response.data['status'] == 'connected' ||
          response.data['connected'] == true) {
        isConnected.value = true;
        isLoading.value = false;
      } else if (response.data['qr'] != null) {
        qrCode.value = response.data['qr'];
        isConnected.value = false;
        isLoading.value = false;
        _startPolling();
      } else {
        // Still initializing, start polling until QR code arrives or connection succeeds
        _startPolling();
      }
    } catch (e) {
      isLoading.value = false;
      Get.snackbar(
        'خطأ الاتصال',
        'فشل الاتصال بخادم الواتساب. تأكد من اتصالك بالإنترنت.',
      );
    }
  }

  Future<void> checkStatus() async {
    try {
      final response = await _apiClient.get('/whatsapp/status');

      if (response.data['error'] != null) {
        _statusTimer?.cancel();
        isLoading.value = false;
        return;
      }

      if (response.data['connected'] == true) {
        isConnected.value = true;
        isLoading.value = false;
        _statusTimer?.cancel();
      } else if (response.data['qr'] != null) {
        qrCode.value = response.data['qr'];
        isLoading.value = false;
      } else {
        // Still waiting for QR code to be generated
        if (_statusTimer == null || !_statusTimer!.isActive) {
           _startPolling();
        }
      }
    } catch (e) {
      // Ignore network errors during polling
    }
  }

  void _startPolling() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!isConnected.value) {
        checkStatus();
      } else {
        timer.cancel();
      }
    });
  }
}
