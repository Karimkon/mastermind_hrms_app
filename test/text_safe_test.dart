import 'package:flutter_test/flutter_test.dart';
import 'package:mastermind_hrms_app/core/services/text_safe.dart';

/// The crash these prevent:
///
///     RangeError (index): Invalid value: Valid value range is empty: 0
///
/// The app was full of `(name ?? '?')[0]`. The `?? '?'` guards null but not
/// the empty string, and a staff record imported from a spreadsheet with a
/// blank name arrives as "", not as null. Indexing that takes down the whole
/// screen — the same shape of failure as the payroll cast, just on a
/// different type.
void main() {
  group('initial', () {
    test('the empty string that actually crashed it', () {
      expect(initial(''), '?');
      expect(initial('   '), '?');
      expect(initial(null), '?');
    });

    test('a real name gives a real letter', () {
      expect(initial('Brenda'), 'B');
      expect(initial('brenda'), 'B');
      expect(initial('  brenda  '), 'B');
    });

    test('the fallback can be chosen', () {
      expect(initial('', fallback: 'M'), 'M');
    });
  });

  group('initialsOf', () {
    test('two words give two letters', () {
      expect(initialsOf('Kansiime Brenda'), 'KB');
    });

    test('one word gives one letter', () {
      expect(initialsOf('Brenda'), 'B');
    });

    test('extra spaces do not produce empty initials', () {
      expect(initialsOf('  Kansiime   Brenda  '), 'KB');
      expect(initialsOf('Kansiime  Brenda Nakato'), 'KB');
    });

    test('nothing to work with falls back', () {
      expect(initialsOf(''), '?');
      expect(initialsOf('   '), '?');
      expect(initialsOf(null), '?');
    });
  });

  group('capitalise and friends', () {
    test('empty stays empty rather than throwing', () {
      expect(capitalise(''), '');
      expect(capitalise(null), '');
      expect(humanise(''), '');
      expect(titleCase(''), '');
    });

    test('a status becomes readable', () {
      expect(capitalise('pending'), 'Pending');
      expect(humanise('on_leave'), 'On leave');
      expect(titleCase('on_leave'), 'On Leave');
    });

    test('already capitalised is left alone', () {
      expect(capitalise('Pending'), 'Pending');
    });
  });

  /// Nothing here may throw, whatever the server sends.
  test('no input throws', () {
    for (final input in <String?>[
      null, '', ' ', '  ', '\t', '\n', 'a', 'A', '_', '__', 'a b c d e',
      '  _  ', 'ñ', '123', '!!!',
    ]) {
      expect(() => initial(input), returnsNormally, reason: 'initial($input)');
      expect(() => initialsOf(input), returnsNormally, reason: 'initialsOf($input)');
      expect(() => capitalise(input), returnsNormally, reason: 'capitalise($input)');
      expect(() => humanise(input), returnsNormally, reason: 'humanise($input)');
      expect(() => titleCase(input), returnsNormally, reason: 'titleCase($input)');
    }
  });
}
