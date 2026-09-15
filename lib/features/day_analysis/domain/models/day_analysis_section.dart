enum DayAnalysisStatus { ok, insufficientData }

enum DayFindingKind { observation, hypothesis }

enum DayFindingConfidence { low, medium, high }

typedef DayAnalysisFinding = ({
  String title,
  String text,
  DayFindingKind kind,
  DayFindingConfidence confidence,
  List<String> evidenceRefs,
});

class DayAnalysisSection {
  final DayAnalysisStatus status;
  final String summary;
  final List<DayAnalysisFinding> findings;
  final List<String> missingData;

  DayAnalysisSection({
    required this.status,
    required this.summary,
    required List<DayAnalysisFinding> findings,
    required List<String> missingData,
  }) : findings = List.unmodifiable(
         findings.map(
           (finding) => (
             title: finding.title,
             text: finding.text,
             kind: finding.kind,
             confidence: finding.confidence,
             evidenceRefs: List<String>.unmodifiable(finding.evidenceRefs),
           ),
         ),
       ),
       missingData = List.unmodifiable(missingData);

  Map<String, Object?> toJson() => {
    'status': status == DayAnalysisStatus.ok ? 'ok' : 'insufficient_data',
    'summary': summary,
    'findings': [
      for (final finding in findings)
        {
          'title': finding.title,
          'text': finding.text,
          'kind': finding.kind.name,
          'confidence': finding.confidence.name,
          'evidence_refs': finding.evidenceRefs,
        },
    ],
    'missing_data': missingData,
  };
}
