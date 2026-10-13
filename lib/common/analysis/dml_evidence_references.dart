import 'dart:convert';

/// Accept only paths to fields actually present in the serialized evidence.
/// Arrays are evidence as a whole; array-index and wildcard paths are unsupported.
Set<String> dmlEvidenceReferences(String text, Set<String> sectionIds) {
  final references = {...sectionIds};
  void fields(String prefix, Map<String, dynamic> value) {
    for (final entry in value.entries) {
      final path = '$prefix.${entry.key}';
      references.add(path);
      if (entry.value is Map<String, dynamic>) {
        fields(path, entry.value as Map<String, dynamic>);
      }
    }
  }

  for (final line in const LineSplitter().convert(text)) {
    final separator = line.indexOf(' ');
    if (separator < 1) continue;
    final id = line.substring(0, separator);
    if (!sectionIds.contains(id)) continue;
    final value = jsonDecode(line.substring(separator + 1));
    if (value is Map<String, dynamic>) fields(id, value);
  }
  return Set.unmodifiable(references);
}
