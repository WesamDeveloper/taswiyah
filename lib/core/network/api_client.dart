import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'endpoints.dart';

class ApiClient {
  late Dio dio;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: Endpoints.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    // Interceptor to attach Authorization Token automatically
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('access_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          // Here we can handle global 401 Unauthorized errors
          return handler.next(e);
        },
      ),
    );
  }

  Future<Response> post(
    String path,
    Map<String, dynamic> map, {
    dynamic data,
  }) async {
    return await dio.post(path, data: data ?? map);
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return await dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> put(
    String path, {
    dynamic data,
  }) async {
    return await dio.put(path, data: data);
  }

  Future<Response> delete(
    String path, {
    dynamic data,
  }) async {
    return await dio.delete(path, data: data);
  }
}
