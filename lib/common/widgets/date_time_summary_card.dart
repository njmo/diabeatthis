import 'package:flutter/material.dart';

import 'section_surface.dart';

class DateTimeSummaryCard extends StatelessWidget {
  const DateTimeSummaryCard({
    super.key,
    required this.title,
    required this.dateTime,
    required this.actionLabel,
    required this.onChange,
    this.details,
  });

  final String title;
  final DateTime dateTime;
  final String actionLabel;
  final VoidCallback onChange;
  final Widget? details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
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
                    Text(
                      '${localizations.formatMediumDate(dateTime)} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(dateTime), alwaysUse24HourFormat: true)}',
                      style: theme.textTheme.titleMedium,
                    ),
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
