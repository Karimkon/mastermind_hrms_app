/// Reading numbers out of JSON without trusting the server's type.
///
/// A payroll run crashed the app with:
///
///     type 'String' is not a subtype of type 'num?' in type cast
///
/// because the API totals come from a database SUM() over a DECIMAL column.
/// PDO hands those back as strings, so the JSON carried "71444500.00" with
/// the quotes, and `value as num?` threw. The screen rendered Flutter's red
/// error page — which, had App Review opened Payroll Runs, is a 2.1 rejection
/// on its own.
///
/// The server now casts those totals, but every other DECIMAL column in the
/// system is one `->sum()` or one missing `$casts` entry away from the same
/// crash. A money column arriving as a string is not an exceptional
/// circumstance in Laravel; it is the default. So the app stops asserting the
/// type and reads it instead.
library;

/// A number from anything reasonable: num, numeric String, or null.
/// Returns null rather than throwing when it genuinely is not a number.
num? asNumOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  if (value is String) return num.tryParse(value.trim());
  if (value is bool) return value ? 1 : 0;
  return null;
}

double? asDoubleOrNull(dynamic value) => asNumOrNull(value)?.toDouble();

int? asIntOrNull(dynamic value) {
  final n = asNumOrNull(value);

  // round() throws UnsupportedError on NaN and infinity, which would defeat
  // the entire purpose of this file. Found by the "no input throws" test.
  if (n == null || !n.isFinite) return null;

  return n.round();
}

/// A number, or [fallback] when the value is missing or unreadable.
double asDouble(dynamic value, [double fallback = 0]) =>
    asDoubleOrNull(value) ?? fallback;

int asInt(dynamic value, [int fallback = 0]) => asIntOrNull(value) ?? fallback;
