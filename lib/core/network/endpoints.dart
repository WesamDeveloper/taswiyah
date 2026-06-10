class Endpoints {
  // Use 192.168.1.105 for physical devices on same Wi-Fi, 10.0.2.2 for Android Emulator
  //static const String baseUrl = 'http://192.168.1.105:8000/api/v1';
  static const String baseUrl = 'https://wesam.alwaysdata.net/api/v1';

  // Auth
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  // Modules
  static const String branches = '/branches';
  static const String customers = '/customers';
  static const String invoices = '/invoices';
  static const String debts = '/debts';
  static const String payments = '/payments';
}
