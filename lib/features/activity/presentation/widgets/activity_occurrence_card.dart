import 'package:flutter/material.dart';

import '../../../../common/presentation/widgets/activity_occurrence_view.dart';
import '../../../../core/drift/database_impl.dart';

class ActivityOccurrenceCard extends StatelessWidget {
  const ActivityOccurrenceCard({
    super.key,
    required this.row,
    required this.name,
    required this.onConfirm,
    required this.onSkip,
    required this.onMove,
    required this.onHistory,
    this.onDelete,
  });
  final ActivityOccurrenceData row;
  final String name;
  final VoidCallback onConfirm;
  final VoidCallback onSkip;
  final VoidCallback onMove;
  final VoidCallback onHistory;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) => ActivityOccurrenceView(
    startedAt: row.startedAt,
    durationMinutes: row.durationMinutes,
    status: row.status,
    recurring: row.scheduleId != null,
    name: name,
    onConfirm: onConfirm,
    onSkip: onSkip,
    onMove: onMove,
    onHistory: onHistory,
    onDelete: onDelete,
  );
}
