import 'package:dio/dio.dart';

class ApiClient {
  ApiClient() : _dio = Dio();

  final Dio _dio;

  Future<Response<dynamic>> get(String path) => _dio.get(path);
}
