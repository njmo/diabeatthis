import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import '../l10n/language.dart';

/// A shared, collapsible calendar-day section for history lists.
class HistoryDaySection extends StatelessWidget {
  const HistoryDaySection({
    super.key,
    required this.date,
    required this.itemCount,
    required this.itemBuilder,
  });

  final DateTime? date;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    final local = date?.toLocal();
    final now = clock.now().toLocal();
    final today = DateTime.utc(now.year, now.month, now.day);
    final days = local == null
        ? null
        : today
              .difference(DateTime.utc(local.year, local.month, local.day))
              .inDays;
    final relative = switch (days) {
      null => context.lang.mealProgressNoDate,
      0 => context.lang.mealTodayLabel,
      1 => context.lang.mealYesterdayLabel,
      < 0 => context.lang.mealDaysFromNow(-days),
      _ => context.lang.mealDaysAgo(days),
    };

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey('history-day-${local?.toIso8601String()}'),
        initiallyExpanded: true,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          local == null
              ? context.lang.mealProgressNoDate
              : MaterialLocalizations.of(context).formatCompactDate(local),
        ),
        subtitle: Text('$relative · $itemCount'),
        children: [
          for (var index = 0; index < itemCount; index++) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder(context, index),
          ],
        ],
      ),
    );
  }
}
