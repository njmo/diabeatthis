import 'dart:convert';

/// Reads both supported DML/1 envelopes without treating a missing section as empty.
Map<String, dynamic> dmlFactsById(String text, String id) {
  for (final line in const LineSplitter().convert(text)) {
    final split = line.indexOf(' ');
    if (split < 1) continue;
    final facts = jsonDecode(line.substring(split + 1));
    if (facts is! Map<String, dynamic>) continue;
    if ((facts['id'] ?? line.substring(0, split)) == id) return facts;
  }
  throw StateError('Missing DML section $id');
}
