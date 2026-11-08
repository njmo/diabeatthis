import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import '../../widgets/history_entry_row.dart';
import 'meal_entry_metadata.dart';

/// A meal entry independent of storage, with optional read-only detail content.
class MealEntryCard extends StatelessWidget {
  const MealEntryCard({
    super.key,
    required this.name,
    required this.status,
    this.plannedAt,
    this.statusLabel,
    this.onTap,
    this.details,
    this.onRetry,
    this.additionalMetadata = const [],
  });

  final List<Widget> additionalMetadata;
  final String name;
  final String status;
  final DateTime? plannedAt;
  final String? statusLabel;
  final VoidCallback? onTap;
  final List<Widget>? details;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final metadata = [
      ...mealEntryMetadata(
        context,
        status: status,
        plannedAt: plannedAt,
        statusLabel: statusLabel,
      ),
      ...additionalMetadata,
      if (onRetry != null)
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(context.lang.familyPlanRetry),
        ),
    ];
    if (details == null) {
      return HistoryEntryRow(name: name, metadata: metadata, onTap: onTap);
    }
    return Card(
      child: ExpansionTile(
        title: Text(name),
        subtitle: Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: metadata,
        ),
        childrenPadding: const EdgeInsets.all(12),
        children: details!,
      ),
    );
  }
}
