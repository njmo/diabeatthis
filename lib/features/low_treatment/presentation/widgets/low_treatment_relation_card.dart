import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/models/timeline_relation.dart';
import '../../../../common/widgets/section_surface.dart';

class LowTreatmentRelationCard extends StatelessWidget {
  const LowTreatmentRelationCard({
    super.key,
    required this.relation,
    this.automatic,
    required this.onChange,
    required this.onDetach,
  });

  final TimelineRelation relation;
  final bool? automatic;
  final VoidCallback? onChange;
  final VoidCallback? onDetach;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionSurface(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              relation.kind == TimelineRelationKind.activity
                  ? Icons.directions_run_rounded
                  : Icons.restaurant_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(relation.name, style: theme.textTheme.titleSmall),
                Text(
                  DateFormat('dd.MM HH:mm').format(relation.at),
                  style: theme.textTheme.bodySmall,
                ),
                if (automatic != null)
                  Text(
                    automatic!
                        ? context.lang.lowTreatmentAutomatic
                        : context.lang.lowTreatmentManual,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.lang.lowTreatmentRelationChange,
            onPressed: onChange,
            icon: const Icon(Icons.edit_rounded),
          ),
          IconButton(
            tooltip: context.lang.lowTreatmentRelationDetach,
            onPressed: onDetach,
            icon: const Icon(Icons.link_off_rounded),
          ),
        ],
      ),
    );
  }
}
