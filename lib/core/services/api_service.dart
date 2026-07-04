import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import 'storage_service.dart';

class ApiService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
  ))
    ..interceptors.add(_AuthInterceptor())
    ..interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
      error: true,
    ));

  static Dio get dio => _dio;

  static Future<Response> get(String path, {Map<String, dynamic>? params}) =>
      _dio.get(path, queryParameters: params);

  static Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);

  static Future<Response> put(String path, {dynamic data}) =>
      _dio.put(path, data: data);

  static Future<Response> delete(String path) => _dio.delete(path);

  static Future<Response> postForm(String path, FormData data) =>
      _dio.post(path, data: data, options: Options(contentType: 'multipart/form-data'));
}

class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await StorageService.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err);
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  factory ApiException.fromDio(DioException e) {
    final data = e.response?.data;
    final message = (data is Map ? data['message'] : null) ??
        e.message ??
        'An error occurred';
    return ApiException(message, statusCode: e.response?.statusCode);
  }

  @override
  String toString() => message;
}
