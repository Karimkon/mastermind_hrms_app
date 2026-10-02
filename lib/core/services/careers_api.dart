import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';
import 'api_service.dart';

/// The careers API, on its own client with its own token.
///
/// Deliberately not ApiService. That client attaches the employee token to
/// every request; a job seeker must never send one, and an employee signed in
/// on the same phone must not have their token sent to the careers endpoints.
/// Two clients, two keys in secure storage, no way for one to borrow the
/// other's credentials.
class CareersApi {
  static const _tokenKey = 'careers_token';

  static const _storage = FlutterSecureStorage(
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    headers: {'Accept': 'application/json'},
  ))..interceptors.add(_SeekerAuthInterceptor());

  static Future<String?> token() => _storage.read(key: _tokenKey);
  static Future<void> saveToken(String t) => _storage.write(key: _tokenKey, value: t);
  static Future<void> clearToken() => _storage.delete(key: _tokenKey);
  static Future<bool> get hasToken async => (await token()) != null;

  // ---- browsing, no account needed ----

  static Future<Map<String, dynamic>> jobs({int? categoryId, String? search, int page = 1}) =>
      _get('/careers/jobs', {
        'category': ?categoryId,
        if (search != null && search.isNotEmpty) 'search': search,
        'page': page,
      });

  static Future<Map<String, dynamic>> job(int id) => _get('/careers/jobs/$id');

  static Future<Map<String, dynamic>> categories() => _get('/careers/categories');

  static Future<Map<String, dynamic>> track(String code) => _get('/careers/track/$code');

  // ---- account ----

  static Future<Map<String, dynamic>> register(Map<String, dynamic> body) =>
      _post('/careers/register', body);

  static Future<Map<String, dynamic>> login(String email, String password) =>
      _post('/careers/login', {'email': email, 'password': password});

  static Future<Map<String, dynamic>> me() => _get('/careers/me');

  static Future<Map<String, dynamic>> updateMe(Map<String, dynamic> body) async {
    try {
      final r = await _dio.put('/careers/me', data: body);
      return Map<String, dynamic>.from(r.data as Map);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  static Future<void> logout() async {
    // Drop the token locally whatever the server says. A seeker tapping sign
    // out must end up signed out even with no signal.
    try {
      await _dio.post('/careers/logout');
    } catch (_) {
      // nothing to do
    }
    await clearToken();
  }

  // ---- applications ----

  static Future<Map<String, dynamic>> apply(int jobId, FormData form) async {
    try {
      final r = await _dio.post(
        '/careers/jobs/$jobId/apply',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      return Map<String, dynamic>.from(r.data as Map);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Apply, reporting how far the upload has got.
  ///
  /// A full set of documents over a phone connection is a slow upload, and a
  /// spinner that says nothing for ninety seconds reads as a hung app. The
  /// callback drives the percentage on the form.
  static Future<Map<String, dynamic>> applyWithProgress(
    int jobId,
    FormData form,
    void Function(int sent, int total) onProgress,
  ) async {
    try {
      final r = await _dio.post(
        '/careers/jobs/$jobId/apply',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
        onSendProgress: onProgress,
      );
      return Map<String, dynamic>.from(r.data as Map);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  static Future<Map<String, dynamic>> applications() => _get('/careers/applications');

  static Future<Map<String, dynamic>> application(int id) => _get('/careers/applications/$id');

  // ---- notifications ----

  static Future<Map<String, dynamic>> notifications() => _get('/careers/notifications');

  static Future<Map<String, dynamic>> markRead({int? id}) =>
      _post('/careers/notifications/read', {'id': ?id});

  // ---- plumbing ----

  static Future<Map<String, dynamic>> _get(String path, [Map<String, dynamic>? params]) async {
    try {
      final r = await _dio.get(path, queryParameters: params);
      return Map<String, dynamic>.from(r.data as Map);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    try {
      final r = await _dio.post(path, data: body);
      return Map<String, dynamic>.from(r.data as Map);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

class _SeekerAuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final t = await CareersApi.token();
    if (t != null) options.headers['Authorization'] = 'Bearer $t';
    handler.next(options);
  }
}
