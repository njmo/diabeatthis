import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';

import '../../../day_analysis/presentation/widgets/day_date_selector.dart';
import 'caregiver_day_summary.dart';

/// The Day tab shows factual summaries; record browsing belongs to History.
class CaregiverDayView extends StatelessWidget {
  const CaregiverDayView({
    super.key,
    required this.date,
    required this.today,
    required this.onDateSelected,
    required this.onRefresh,
    this.owner,
    this.source,
    this.revision = 0,
  });

  final DateTime date, today;
  final ValueChanged<DateTime?> onDateSelected;
  final Future<void> Function() onRefresh;
  final String? owner, source;
  final int revision;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        12,
        0,
        12,
        112 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        DayDateSelector(
          date: date,
          today: today,
          onSelected: onDateSelected,
          actions: [
            IconButton(
              tooltip: context.lang.dayRefresh,
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 8),
        CaregiverDaySummary(
          date: date,
          owner: owner,
          source: source,
          revision: revision,
        ),
      ],
    ),
  );
}
