import 'dart:convert';

import 'analysis_section.dart';

Map<String, AnalysisSection> parseAnalysisSections(
  String response, {
  required String language,
  required Set<String> evidenceIds,
  required List<String> sectionNames,
  int findingTextLimit = 600,
  int evidenceRefsLimit = 8,
}) {
  if (response.length > 32000) {
    throw const FormatException('Structured analysis is too large');
  }
  try {
    final root = jsonDecode(response) as Map<String, dynamic>;
    _keys(root, ['schema_version', 'language', 'sections']);
    if (root['schema_version'] != 1 || root['language'] != language) {
      throw const FormatException(
        'Unexpected structured analysis version or language',
      );
    }
    final rawSections = root['sections'] as Map<String, dynamic>;
    final expectedSections = sectionNames;
    _keys(rawSections, expectedSections);
    final sections = <String, AnalysisSection>{};
    for (final name in expectedSections) {
      final raw = rawSections[name] as Map<String, dynamic>;
      _keys(raw, ['status', 'summary', 'findings', 'missing_data']);
      final status = switch (raw['status']) {
        'ok' => AnalysisStatus.ok,
        'insufficient_data' => AnalysisStatus.insufficientData,
        _ => throw const FormatException('Invalid section status'),
      };
      final findings = raw['findings'] as List;
      if (findings.length > 1) {
        throw const FormatException('Too many findings');
      }
      final parsed = <AnalysisFinding>[];
      for (final item in findings) {
        final finding = item as Map<String, dynamic>;
        _keys(finding, [
          'title',
          'text',
          'kind',
          'confidence',
          'evidence_refs',
        ]);
        final refs = _strings(finding['evidence_refs'], max: evidenceRefsLimit);
        if (refs.isEmpty || refs.any((id) => !evidenceIds.contains(id))) {
          throw const FormatException('Unknown or missing evidence');
        }
        parsed.add((
          title: _text(finding['title'], max: 80),
          text: _text(finding['text'], max: findingTextLimit),
          kind: AnalysisFindingKind.values.byName(finding['kind'] as String),
          confidence: AnalysisFindingConfidence.values.byName(
            finding['confidence'] as String,
          ),
          evidenceRefs: refs,
        ));
      }
      sections[name] = AnalysisSection(
        status: status,
        summary: _text(raw['summary'], max: 320, allowEmpty: true),
        findings: parsed,
        missingData: _strings(raw['missing_data'], max: 12),
      );
    }
    return Map.unmodifiable(sections);
  } on FormatException {
    rethrow;
  } on TypeError {
    throw const FormatException('Invalid structured analysis field type');
  } on ArgumentError {
    throw const FormatException('Invalid structured analysis field value');
  }
}

void _keys(Map<String, dynamic> value, List<String> expected) {
  if (value.length != expected.length ||
      expected.any((key) => !value.containsKey(key))) {
    throw const FormatException('Unexpected structured analysis fields');
  }
}

String _text(dynamic value, {required int max, bool allowEmpty = false}) {
  if (value is! String ||
      value.length > max ||
      (!allowEmpty && value.trim().isEmpty)) {
    throw const FormatException('Invalid structured analysis text');
  }
  return value;
}

List<String> _strings(dynamic value, {required int max}) {
  final list = value as List;
  if (list.length > max) {
    throw const FormatException('Too many structured analysis items');
  }
  return list.map((item) => _text(item, max: 160)).toList();
}
