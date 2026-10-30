/// String helpers that cannot throw on an empty value.
///
/// The app is full of `(name ?? '?')[0]` and `status[0].toUpperCase()`. The
/// `?? '?'` guards null, but not the empty string — and an employee whose
/// name has never been filled in arrives as `""`, not as null. Indexing `[0]`
/// on that throws:
///
///     RangeError (index): Invalid value: Valid value range is empty: 0
///
/// which takes down the whole screen, the same way the payroll cast did. With
/// 1,977 staff records imported from spreadsheets, a blank name somewhere is
/// not a hypothetical.
library;

/// First letter for an avatar, or `?` when there is nothing to show.
String initial(String? value, {String fallback = '?'}) {
  final s = value?.trim() ?? '';
  return s.isEmpty ? fallback : s[0].toUpperCase();
}

/// Up to two initials from a name (named initialsOf, not initials, because
/// several screens already keep a local variable called initials): "Kansiime Brenda" becomes "KB".
String initialsOf(String? value, {String fallback = '?'}) {
  final parts = (value ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();

  if (parts.isEmpty) return fallback;
  if (parts.length == 1) return parts.first[0].toUpperCase();

  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

/// "pending" becomes "Pending". Empty stays empty rather than throwing.
String capitalise(String? value) {
  final s = value?.trim() ?? '';
  return s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1);
}

/// "on_leave" becomes "On leave". Handles the snake_case the API sends.
String humanise(String? value) {
  final s = (value ?? '').trim().replaceAll('_', ' ');
  return capitalise(s);
}

/// Every word capitalised: "on_leave" becomes "On Leave".
String titleCase(String? value) {
  final words = (value ?? '')
      .trim()
      .replaceAll('_', ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map(capitalise);

  return words.join(' ');
}
