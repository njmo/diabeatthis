import 'dart:convert';

import 'day_analysis_section.dart';

class DayAnalysisResult {
  static const schemaVersion = 1;
  static const sectionNames = [
    'overview',
    'glucose',
    'night',
    'insulin',
    'meals',
    'low_treatments',
    'activity',
    'devices',
  ];
  final String language;
  final Map<String, DayAnalysisSection> sections;

  DayAnalysisResult._(this.language, Map<String, DayAnalysisSection> sections)
    : sections = Map.unmodifiable(sections);

  /// Reject malformed/truncated output and invented evidence before UI or storage.
  factory DayAnalysisResult.parse(
    String response, {
    required String language,
    required Set<String> evidenceIds,
    List<String> mealSectionIds = const [],
  }) {
    if (response.length > 32000) {
      throw const FormatException('Day analysis is too large');
    }
    try {
      final root = jsonDecode(response) as Map<String, dynamic>;
      _keys(root, ['schema_version', 'language', 'sections']);
      if (root['schema_version'] != schemaVersion ||
          root['language'] != language) {
        throw const FormatException(
          'Unexpected day analysis version or language',
        );
      }
      final rawSections = root['sections'] as Map<String, dynamic>;
      final expectedSections = [...sectionNames, ...mealSectionIds];
      _keys(rawSections, expectedSections);
      final sections = <String, DayAnalysisSection>{};
      for (final name in expectedSections) {
        final raw = rawSections[name] as Map<String, dynamic>;
        _keys(raw, ['status', 'summary', 'findings', 'missing_data']);
        final status = switch (raw['status']) {
          'ok' => DayAnalysisStatus.ok,
          'insufficient_data' => DayAnalysisStatus.insufficientData,
          _ => throw const FormatException('Invalid section status'),
        };
        final findings = raw['findings'] as List;
        if (findings.length > 1) {
          throw const FormatException('Too many findings');
        }
        final parsed = <DayAnalysisFinding>[];
        for (final item in findings) {
          final finding = item as Map<String, dynamic>;
          _keys(finding, [
            'title',
            'text',
            'kind',
            'confidence',
            'evidence_refs',
          ]);
          final refs = _strings(finding['evidence_refs'], max: 8);
          if (refs.isEmpty || refs.any((id) => !evidenceIds.contains(id))) {
            throw const FormatException('Unknown or missing evidence');
          }
          parsed.add((
            title: _text(finding['title'], max: 80),
            text: _text(finding['text'], max: 600),
            kind: DayFindingKind.values.byName(finding['kind'] as String),
            confidence: DayFindingConfidence.values.byName(
              finding['confidence'] as String,
            ),
            evidenceRefs: refs,
          ));
        }
        sections[name] = DayAnalysisSection(
          status: status,
          summary: _text(raw['summary'], max: 320, allowEmpty: true),
          findings: parsed,
          missingData: _strings(raw['missing_data'], max: 12),
        );
      }
      return DayAnalysisResult._(language, sections);
    } on FormatException {
      rethrow;
    } on TypeError {
      throw const FormatException('Invalid day analysis field type');
    } on ArgumentError {
      throw const FormatException('Invalid day analysis field value');
    }
  }

  String encode() => jsonEncode({
    'schema_version': schemaVersion,
    'language': language,
    'sections': {
      for (final entry in sections.entries) entry.key: entry.value.toJson(),
    },
  });
}

void _keys(Map<String, dynamic> value, List<String> expected) {
  if (value.length != expected.length ||
      expected.any((key) => !value.containsKey(key))) {
    throw const FormatException('Unexpected day analysis fields');
  }
}

String _text(dynamic value, {required int max, bool allowEmpty = false}) {
  if (value is! String ||
      value.length > max ||
      (!allowEmpty && value.trim().isEmpty)) {
    throw const FormatException('Invalid day analysis text');
  }
  return value;
}

List<String> _strings(dynamic value, {required int max}) {
  final list = value as List;
  if (list.length > max) {
    throw const FormatException('Too many day analysis items');
  }
  return list.map((item) => _text(item, max: 160)).toList();
}
