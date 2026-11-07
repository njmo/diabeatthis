import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import '../../presentation/widgets/activity_occurrence_view.dart';
import 'family_plan_snapshot_view.dart';

class FamilyPlannedActivityCard extends StatelessWidget {
  const FamilyPlannedActivityCard({
    super.key,
    required this.payload,
    required this.name,
    required this.locked,
    this.onConfirm,
    this.monitoring = false,
    this.requestStatusLabel,
    this.onRetry,
    this.onMove,
    this.onSkip,
  });
  final Map payload;
  final String name;
  final bool locked;
  final bool monitoring;
  final String? requestStatusLabel;
  final VoidCallback? onRetry;
  final VoidCallback? onConfirm;
  final VoidCallback? onMove;
  final VoidCallback? onSkip;
  @override
  Widget build(BuildContext context) {
    return ActivityOccurrenceView(
      onRetry: onRetry,
      startedAt: payload['started_at'] as int,
      durationMinutes: payload['duration_minutes'] as int?,
      status: payload['status'] as String,
      recurring: payload['schedule_id'] != null,
      name: name,
      statusLabel: monitoring
          ? context.lang.familyPlanMonitoring
          : requestStatusLabel ??
                (locked
                    ? context.lang.familyPlanPending
                    : familyPlanExecutionLabel(
                        context,
                        payload['status'] as String,
                      )),
      onConfirm: locked || monitoring ? null : onConfirm,
      onSkip: locked || monitoring || !['pending','planned'].contains(payload['status']) ? null : onSkip,
      onMove:
          locked ||
              monitoring ||
              !['pending', 'planned'].contains(payload['status'])
          ? null
          : onMove,
    );
  }
}
