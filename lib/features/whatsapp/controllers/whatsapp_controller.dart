import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/network/api_client.dart';

class WhatsappController extends GetxController {
  final ApiClient _apiClient = ApiClient();

  var isLoading = true.obs;
  var isConnected = false.obs;
  var qrCode = ''.obs;

  var pairingCode = ''.obs;

  Timer? _statusTimer;

  @override
  void onInit() {
    super.onInit();
    // Instead of initSession which fetches QR, we just check status initially
    checkStatus();
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
      pairingCode.value = '';
      isConnected.value = false;
      // Wait a moment before checking status again
      await Future.delayed(const Duration(seconds: 2));
      checkStatus();
    } catch (e) {
      isLoading.value = false;
      Get.snackbar('خطأ', 'فشل إعادة ضبط جلسة الواتساب');
    }
  }

  Future<void> requestPairingCode(String phone) async {
    isLoading.value = true;
    pairingCode.value = '';
    qrCode.value = '';
    
    try {
      final response = await _apiClient.post('/whatsapp/pair', {'phone': phone});

      if (response.data['error'] != null) {
        isLoading.value = false;
        Get.snackbar(
          'خطأ',
          'خادم الواتساب غير متصل حالياً',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      } else if (response.data['status'] == 'connected' || response.data['connected'] == true) {
        isConnected.value = true;
        isLoading.value = false;
      } else if (response.data['code'] != null) {
        pairingCode.value = response.data['code'];
        isConnected.value = false;
        isLoading.value = false;
        _startPolling();
      } else {
        isLoading.value = false;
        Get.snackbar('خطأ', 'لم يتم التعرف على الاستجابة من السيرفر');
      }
    } catch (e) {
      isLoading.value = false;
      Get.snackbar(
        'خطأ الاتصال',
        'فشل الاتصال بخادم الواتساب. تأكد من إدخال الرقم بشكل صحيح.',
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
        // No active session or still initializing
        isLoading.value = false;
      }
    } catch (e) {
      isLoading.value = false;
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
