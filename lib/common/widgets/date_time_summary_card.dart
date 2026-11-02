import 'package:flutter/material.dart';

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
    final colors = theme.colorScheme;
    final localizations = MaterialLocalizations.of(context);
    return Card.outlined(
      margin: EdgeInsets.zero,
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: colors.onPrimaryContainer),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onChange,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.onPrimaryContainer,
                    ),
                    child: Text(actionLabel),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 32,
                    color: colors.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.formatTimeOfDay(
                            TimeOfDay.fromDateTime(dateTime),
                            alwaysUse24HourFormat: true,
                          ),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          localizations.formatFullDate(dateTime),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (details != null) ...[
                const SizedBox(height: 12),
                Divider(
                  color: colors.onPrimaryContainer.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 4),
                details!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
