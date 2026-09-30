import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mastermind_hrms_app/core/services/api_service.dart';

/// What somebody actually reads when a request fails.
///
/// Signing in with the wrong password used to put Dio's own essay on the
/// screen — "this exception was thrown because RequestOptions.validateStatus
/// was configured to throw for this status code… read more about status codes
/// at developer.mozilla.org" — because the provider rethrew the raw
/// DioException and the screen printed e.toString().
void main() {
  DioException dio({
    int? status,
    dynamic body,
    DioExceptionType type = DioExceptionType.badResponse,
  }) {
    final options = RequestOptions(path: '/login');
    return DioException(
      requestOptions: options,
      type: type,
      // The long unhelpful text the old code fell back to.
      message: 'This exception was thrown because the response has a status '
          'code of $status and RequestOptions.validateStatus was configured '
          'to throw for this status code.',
      response: status == null
          ? null
          : Response(requestOptions: options, statusCode: status, data: body),
    );
  }

  group('ApiException.fromDio', () {
    test('uses what the server said', () {
      final e = ApiException.fromDio(dio(status: 401, body: {'message': 'Invalid credentials.'}));

      expect(e.message, 'Invalid credentials.');
      expect(e.statusCode, 401);
      expect(e.toString(), 'Invalid credentials.');
    });

    test('never leaks the Dio explanation', () {
      // No message key, so the old code fell straight through to e.message.
      final e = ApiException.fromDio(dio(status: 401, body: {'ok': false}));

      expect(e.message, isNot(contains('validateStatus')));
      expect(e.message, isNot(contains('developer.mozilla.org')));
      expect(e.message, 'Your email or password is not correct.');
    });

    test('a 422 says which field was wrong', () {
      final e = ApiException.fromDio(dio(status: 422, body: {
        'message': '',
        'errors': {
          'review_note': ['Say why, so the account manager knows what to correct.'],
        },
      }));

      expect(e.message, 'Say why, so the account manager knows what to correct.');
    });

    test('losing the connection reads like losing the connection', () {
      final e = ApiException.fromDio(dio(type: DioExceptionType.connectionError));

      expect(e.message, 'Could not reach the server. Check your internet connection.');
      expect(e.statusCode, isNull);
    });

    test('a timeout says so', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(ApiException.fromDio(dio(type: type)).message, contains('took too long'));
      }
    });

    test('each status somebody can hit has its own sentence', () {
      String forStatus(int s) => ApiException.fromDio(dio(status: s, body: null)).message;

      expect(forStatus(403), 'You do not have permission to do that.');
      expect(forStatus(404), 'That could not be found.');
      expect(forStatus(419), contains('session has expired'));
      expect(forStatus(429), contains('Too many attempts'));
      expect(forStatus(500), contains('went wrong on the server'));
      expect(forStatus(503), contains('went wrong on the server'));
    });

    test('a blank server message does not win over a real one', () {
      // An empty string is not an explanation.
      final e = ApiException.fromDio(dio(status: 403, body: {'message': '   '}));

      expect(e.message, 'You do not have permission to do that.');
    });

    test('a response body that is not a map does not break it', () {
      final e = ApiException.fromDio(dio(status: 500, body: '<html>Server Error</html>'));

      expect(e.message, contains('went wrong on the server'));
    });
  });
}
