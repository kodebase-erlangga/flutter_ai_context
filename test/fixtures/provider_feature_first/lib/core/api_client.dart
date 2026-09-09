import 'package:dio/dio.dart';

class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> get(String path) async {
    final response = await _dio.get(path);
    return response.data as Map<String, dynamic>;
  }
}
