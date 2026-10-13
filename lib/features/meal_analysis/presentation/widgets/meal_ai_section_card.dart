import 'package:flutter/material.dart';

import '../../../../common/analysis/analysis_section.dart';
import '../../../../common/l10n/language.dart';

class MealAiSectionCard extends StatelessWidget {
  final String title;
  final AnalysisSection section;
  const MealAiSectionCard({
    super.key,
    required this.title,
    required this.section,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (section.status == AnalysisStatus.insufficientData)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(context.lang.dayAiInsufficientData),
            ),
          if (section.status == AnalysisStatus.ok &&
              section.summary.isEmpty &&
              section.findings.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(context.lang.dayAiNoFindings),
            ),
          if (section.summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(section.summary),
            ),
          for (final finding in section.findings)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (finding.kind == AnalysisFindingKind.hypothesis)
                    Text(
                      context.lang.dayAiHypothesis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  Text(
                    finding.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(finding.text),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
