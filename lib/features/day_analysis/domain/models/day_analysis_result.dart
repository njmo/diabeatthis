import 'dart:convert';

import '../../../../common/analysis/parse_analysis_sections.dart';
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
    return DayAnalysisResult._(
      language,
      parseAnalysisSections(
        response,
        language: language,
        evidenceIds: evidenceIds,
        sectionNames: [...sectionNames, ...mealSectionIds],
      ),
    );
  }

  String encode() => jsonEncode({
    'schema_version': schemaVersion,
    'language': language,
    'sections': {
      for (final entry in sections.entries) entry.key: entry.value.toJson(),
    },
  });
}
