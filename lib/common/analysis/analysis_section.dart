enum AnalysisStatus { ok, insufficientData }

enum AnalysisFindingKind { observation, hypothesis }

enum AnalysisFindingConfidence { low, medium, high }

typedef AnalysisFinding = ({
  String title,
  String text,
  AnalysisFindingKind kind,
  AnalysisFindingConfidence confidence,
  List<String> evidenceRefs,
});

class AnalysisSection {
  final AnalysisStatus status;
  final String summary;
  final List<AnalysisFinding> findings;
  final List<String> missingData;

  AnalysisSection({
    required this.status,
    required this.summary,
    required List<AnalysisFinding> findings,
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
    'status': status == AnalysisStatus.ok ? 'ok' : 'insufficient_data',
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
