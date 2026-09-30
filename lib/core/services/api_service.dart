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

  /// The sentence to put in front of somebody.
  ///
  /// This used to fall back to `e.message`, which for a bad response is Dio's
  /// own essay — "this exception was thrown because RequestOptions.validateStatus
  /// was configured to throw for this status code… read more about status codes
  /// at developer.mozilla.org". Somebody mistyping their password was shown all
  /// of it. The server already says what went wrong; when it does not, the
  /// status and the failure type do.
  factory ApiException.fromDio(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    // What the server itself said, which is nearly always the right answer.
    if (data is Map) {
      final said = data['message'];
      if (said is String && said.trim().isNotEmpty) {
        return ApiException(said.trim(), statusCode: status);
      }

      // A 422 carries its detail in `errors` rather than `message`.
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) {
          return ApiException(first.first.toString(), statusCode: status);
        }
      }
    }

    final message = switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'The server took too long to answer. Check your connection and try again.',
      DioExceptionType.connectionError =>
        'Could not reach the server. Check your internet connection.',
      DioExceptionType.cancel => 'That request was cancelled.',
      DioExceptionType.badCertificate =>
        'The server\'s security certificate could not be trusted.',
      _ => switch (status) {
          401 => 'Your email or password is not correct.',
          403 => 'You do not have permission to do that.',
          404 => 'That could not be found.',
          419 => 'Your session has expired. Please sign in again.',
          422 => 'Some of what you entered was not accepted.',
          429 => 'Too many attempts. Wait a moment and try again.',
          >= 500 => 'Something went wrong on the server. Please try again.',
          _ => 'Something went wrong. Please try again.',
        },
    };

    return ApiException(message, statusCode: status);
  }

  @override
  String toString() => message;
}
