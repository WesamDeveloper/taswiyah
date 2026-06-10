import 'dart:async';
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

  Future<void> initSession() async {
    isLoading.value = true;
    try {
      final response = await _apiClient.get('/whatsapp/qr');
      
      if (response.data['status'] == 'connected' || response.data['connected'] == true) {
        isConnected.value = true;
        isLoading.value = false;
      } else if (response.data['qr'] != null) {
        qrCode.value = response.data['qr'];
        isConnected.value = false;
        isLoading.value = false;
        _startPolling();
      } else {
        // Still initializing, wait and check
        Future.delayed(const Duration(seconds: 3), () => checkStatus());
      }
    } catch (e) {
      isLoading.value = false;
    }
  }

  Future<void> checkStatus() async {
    try {
      final response = await _apiClient.get('/whatsapp/status');
      
      if (response.data['connected'] == true) {
        isConnected.value = true;
        isLoading.value = false;
        _statusTimer?.cancel();
      } else if (response.data['qr'] != null) {
        qrCode.value = response.data['qr'];
        isLoading.value = false;
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
