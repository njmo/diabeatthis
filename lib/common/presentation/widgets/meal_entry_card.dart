import 'package:flutter/material.dart';

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
  });

  final String name;
  final String status;
  final DateTime? plannedAt;
  final String? statusLabel;
  final VoidCallback? onTap;
  final List<Widget>? details;

  @override
  Widget build(BuildContext context) {
    final metadata = mealEntryMetadata(
      context,
      status: status,
      plannedAt: plannedAt,
      statusLabel: statusLabel,
    );
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
