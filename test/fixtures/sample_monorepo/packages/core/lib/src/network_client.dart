import 'package:dio/dio.dart';

class NetworkClient {
  NetworkClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<Response<T>> get<T>(String path) => _dio.get(path);
}
