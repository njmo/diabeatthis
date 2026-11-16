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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final numColor =
        isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final mutedColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderColor),
      ),
      child: ExpansionTile(
        key: PageStorageKey('history-day-${local?.toIso8601String()}'),
        initiallyExpanded: true,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          local == null
              ? context.lang.mealProgressNoDate
              : MaterialLocalizations.of(context).formatCompactDate(local),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: numColor,
          ),
        ),
        subtitle: Text(
          '$relative · $itemCount',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: mutedColor,
          ),
        ),
        children: [
          for (var index = 0; index < itemCount; index++) ...[
            Divider(height: 1, indent: 16, endIndent: 16, color: borderColor),
            itemBuilder(context, index),
          ],
        ],
      ),
    );
  }
}
