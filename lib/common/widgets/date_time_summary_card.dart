import 'package:flutter/material.dart';

import 'section_surface.dart';

class DateTimeSummaryCard extends StatelessWidget {
  const DateTimeSummaryCard({
    super.key,
    required this.title,
    required DateTime this.dateTime,
    required this.actionLabel,
    required this.onChange,
    this.details,
  }) : valueLabel = null;

  const DateTimeSummaryCard.labeled({
    super.key,
    required this.title,
    required String this.valueLabel,
    required this.actionLabel,
    required this.onChange,
  }) : dateTime = null,
       details = null;

  final String title;
  final DateTime? dateTime;
  final String? valueLabel;
  final String actionLabel;
  final VoidCallback onChange;
  final Widget? details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final date = dateTime;
    final label = date == null
        ? valueLabel!
        : '${localizations.formatMediumDate(date)} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date), alwaysUse24HourFormat: true)}';
    return SectionSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Text(label, style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
              IconButton(
                tooltip: actionLabel,
                onPressed: onChange,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          if (details != null) ...[
            const SizedBox(height: 12),
            const Divider(),
            details!,
          ],
        ],
      ),
    );
  }
}
