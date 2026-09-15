import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../domain/models/day_analysis_result.dart';
import '../../domain/models/day_analysis_section.dart';
import 'day_summary_card.dart';

class DayAiResult extends StatelessWidget {
  final DayAnalysisResult result;
  final Map<String, ({String name, DateTime at})> meals;
  const DayAiResult({super.key, required this.result, this.meals = const {}});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final titles = {
      for (final entry in meals.entries)
        entry.key:
            '${DateFormat.Hm(lang.localeName).format(entry.value.at.toLocal())} · ${entry.value.name}',
      'overview': lang.dayAiOverview,
      'glucose': lang.dayGlucoseTitle,
      'night': lang.dayNightSectionTitle,
      'insulin': lang.dayInsulinTitle,
      'meals': lang.managementMealsTab,
      'low_treatments': lang.activityExtraTreatLabel,
      'activity': lang.dayActivityTitle,
      'devices': lang.dayDevicesTitle,
    };
    final visible = result.sections.entries
        .where(
          (entry) =>
              entry.value.summary.isNotEmpty || entry.value.findings.isNotEmpty,
        )
        .toList();
    if (visible.isEmpty) {
      final insufficient = result.sections.values.any(
        (section) => section.status == DayAnalysisStatus.insufficientData,
      );
      return Text(
        insufficient ? lang.dayAiInsufficientData : lang.dayAiNoFindings,
      );
    }
    return Column(
      children: [
        for (final entry in visible)
          DaySummaryCard(
            title: titles[entry.key]!,
            warnings: [
              if (entry.value.status == DayAnalysisStatus.insufficientData)
                lang.dayAiInsufficientData,
            ],
            children: [
              if (entry.value.summary.isNotEmpty) Text(entry.value.summary),
              for (final finding in entry.value.findings)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (finding.kind == DayFindingKind.hypothesis)
                        Text(
                          lang.dayAiHypothesis,
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
      ],
    );
  }
}
