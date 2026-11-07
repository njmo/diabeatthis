import 'package:flutter/material.dart';

import '../../../features/meals/presentation/widgets/meal_details/meal_detail_formatters.dart';
import '../../widgets/history_status_badge.dart';

/// Presentation-only metadata: neither source nor permitted actions live here.
List<Widget> mealEntryMetadata(
  BuildContext context, {
  required String status,
  DateTime? plannedAt,
  String? statusLabel,
}) => [
  HistoryStatusBadge(label: statusLabel ?? mealStatusLabel(status)),
  if (plannedAt != null)
    Text(
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(plannedAt.toLocal()),
        alwaysUse24HourFormat: true,
      ),
      style: Theme.of(context).textTheme.bodyMedium,
    ),
];
