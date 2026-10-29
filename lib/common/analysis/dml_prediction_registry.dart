import 'dart:convert';

/// Document-local references deduplicate exact forecast facts, never merely times.
/// A different curve at the same calculation time remains separate evidence.
class DmlPredictionRegistry {
  final Map<String, String> _ids = {};
  final Map<String, Map<String, Object?>> _facts = {};

  String register(Map<String, Object?> facts) {
    final encoded = jsonEncode(_ordered(facts));
    return _ids.putIfAbsent(encoded, () {
      final id = 'prediction_${_ids.length + 1}';
      _facts[id] = jsonDecode(encoded) as Map<String, dynamic>;
      return id;
    });
  }

  Iterable<({String id, Map<String, Object?> facts})> get entries sync* {
    for (final entry in _facts.entries) {
      yield (id: entry.key, facts: Map.unmodifiable(entry.value));
    }
  }
}

Object? _ordered(Object? value) {
  if (value is Map<String, Object?>) {
    final keys = value.keys.toList()..sort();
    return {for (final key in keys) key: _ordered(value[key])};
  }
  if (value is List) return value.map(_ordered).toList();
  return value;
}
