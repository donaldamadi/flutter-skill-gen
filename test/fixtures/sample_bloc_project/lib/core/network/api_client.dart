import 'package:dio/dio.dart';

class ApiClient {
  ApiClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<Response<T>> get<T>(String path) => _dio.get(path);

  Future<Response<T>> post<T>(String path, {Object? data}) =>
      _dio.post(path, data: data);
}
