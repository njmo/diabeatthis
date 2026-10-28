import 'dart:convert';

/// Precision applies only to the exported text, never to source calculations.
String encodeDmlFacts(Map<String, Object?> facts) =>
    jsonEncode(_compact(facts));

Object? _compact(Object? value) {
  if (value is double) {
    if (!value.isFinite) return null;
    final rounded = double.parse(value.toStringAsFixed(4));
    return rounded.abs() < 9007199254740992 &&
            rounded == rounded.truncateToDouble()
        ? rounded.toInt()
        : rounded;
  }
  if (value is Map<String, Object?>) {
    return value.map((key, entry) => MapEntry(key, _compact(entry)));
  }
  if (value is List) return value.map(_compact).toList();
  return value;
}
