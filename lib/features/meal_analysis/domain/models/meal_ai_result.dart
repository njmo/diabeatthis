import 'dart:convert';

import '../../../../common/analysis/analysis_section.dart';
import '../../../../common/analysis/dml_evidence_references.dart';
import '../../../../common/analysis/parse_analysis_sections.dart';

class MealAiResult {
  static const findingTextLimit = 1200;
  static const evidenceRefsLimit = 16;
  static const sectionNames = ['overview', 'before', 'response', 'comparison'];
  final String language;
  final Map<String, AnalysisSection> sections;
  MealAiResult._(this.language, this.sections);
  factory MealAiResult.parse(
    String text, {
    required String language,
    required Set<String> evidenceIds,
    String? evidenceText,
  }) => MealAiResult._(
    language,
    parseAnalysisSections(
      text,
      language: language,
      evidenceIds: evidenceText == null
          ? evidenceIds
          : dmlEvidenceReferences(evidenceText, evidenceIds),
      findingTextLimit: findingTextLimit,
      evidenceRefsLimit: evidenceRefsLimit,
      sectionNames: sectionNames,
    ),
  );
  String encode() => jsonEncode({
    'schema_version': 1,
    'language': language,
    'sections': {
      for (final entry in sections.entries) entry.key: entry.value.toJson(),
    },
  });
}
