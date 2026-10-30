import 'package:flutter_test/flutter_test.dart';
import 'package:mastermind_hrms_app/core/services/json_num.dart';

/// The crash this prevents, verbatim from the device:
///
///     type 'String' is not a subtype of type 'num?' in type cast
///
/// Payroll Runs rendered Flutter's red error page because the API's totals
/// came from a database SUM() over a DECIMAL column. PDO returns those as
/// strings, so the JSON carried "71444500.00" with the quotes, and the screen
/// cast it `as num?`.
void main() {
  group('the shape that actually crashed the app', () {
    test('a decimal total arriving as a quoted string', () {
      expect(asDouble('71444500.00'), 71444500.0);
      expect(asDouble('61568529.00'), 61568529.0);
    });

    test('the same value arriving as a number still works', () {
      expect(asDouble(71444500), 71444500.0);
      expect(asDouble(71444500.0), 71444500.0);
    });
  });

  group('asDouble', () {
    test('null falls back rather than throwing', () {
      expect(asDouble(null), 0);
      expect(asDouble(null, 5), 5);
    });

    test('an unreadable value falls back rather than throwing', () {
      expect(asDouble('not a number'), 0);
      expect(asDouble(''), 0);
      expect(asDouble([]), 0);
      expect(asDouble({}), 0);
    });

    test('whitespace around a number is tolerated', () {
      expect(asDouble('  1234.50  '), 1234.5);
    });

    test('negative and zero survive', () {
      expect(asDouble('-500.25'), -500.25);
      expect(asDouble('0'), 0);
      expect(asDouble('0.00'), 0);
    });
  });

  group('asInt', () {
    test('reads a string', () => expect(asInt('439'), 439));
    test('rounds a decimal string', () => expect(asInt('439.6'), 440));
    test('falls back on nonsense', () => expect(asInt('x', 7), 7));
  });

  group('the nullable variants keep null meaningful', () {
    test('null stays null, so "absent" and "zero" stay different', () {
      expect(asDoubleOrNull(null), isNull);
      expect(asIntOrNull(null), isNull);
      expect(asNumOrNull(null), isNull);
    });

    test('an unreadable value is null, not zero', () {
      expect(asDoubleOrNull('abc'), isNull);
    });

    test('a real zero is zero, not null', () {
      expect(asDoubleOrNull('0.00'), 0);
    });
  });

  /// Nothing in here may ever throw. That is the whole point: a money column
  /// arriving as a string is the Laravel default, not an edge case.
  test('no input throws', () {
    for (final input in <dynamic>[
      null, '', ' ', 'abc', '12abc', true, false, 0, -1, 1.5,
      '1e5', '-0.0', [], {}, [1, 2], {'a': 1}, double.nan, double.infinity,
    ]) {
      expect(() => asDouble(input), returnsNormally, reason: 'asDouble($input)');
      expect(() => asInt(input), returnsNormally, reason: 'asInt($input)');
      expect(() => asNumOrNull(input), returnsNormally, reason: 'asNumOrNull($input)');
    }
  });
}
