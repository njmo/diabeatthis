import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/models/timeline_relation.dart';
import '../../../../common/widgets/timeline_relation_picker.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../data/repositories/low_treatment_relation_repository.dart';

class LowTreatmentRelationEditor extends HookConsumerWidget {
  const LowTreatmentRelationEditor({
    super.key,
    required this.occurredAt,
    required this.onChanged,
    this.mealId,
    this.relatedMealId,
    this.relatedActivityLogId,
    this.busy = false,
  });
  final DateTime occurredAt;
  final int? mealId;
  final int? relatedMealId;
  final int? relatedActivityLogId;
  final bool busy;
  final Future<void> Function(TimelineRelation?) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final repository = LowTreatmentRelationRepository(db);
    final saving = useState(false);
    final future = useMemoized(
      () => repository.resolve(
        mealId: relatedMealId,
        activityLogId: relatedActivityLogId,
      ),
      [db, relatedMealId, relatedActivityLogId],
    );
    final current = useFuture(future);
    final linked = relatedMealId != null || relatedActivityLogId != null;
    Future<void> save(TimelineRelation? relation) async {
      saving.value = true;
      try {
        await onChanged(relation);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.lang.dayReviewSaveFailed)),
          );
        }
      } finally {
        if (context.mounted) saving.value = false;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (current.data case final relation?)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              relation.kind == TimelineRelationKind.activity
                  ? Icons.directions_run
                  : Icons.restaurant,
            ),
            title: Text(relation.name),
            subtitle: Text(DateFormat('dd.MM.yyyy HH:mm').format(relation.at)),
          ),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.link),
              label: Text(
                linked
                    ? context.lang.lowTreatmentRelationChange
                    : context.lang.lowTreatmentRelationSelect,
              ),
              onPressed: busy || saving.value
                  ? null
                  : () async {
                      final selected =
                          await showModalBottomSheet<TimelineRelation>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => TimelineRelationPicker(
                              occurredAt: occurredAt,
                              load: (day) => repository.load(
                                day,
                                occurredAt,
                                excludeMealId: mealId,
                              ),
                            ),
                          );
                      if (selected != null && context.mounted) {
                        await save(selected);
                      }
                    },
            ),
            if (linked)
              TextButton.icon(
                icon: const Icon(Icons.link_off),
                label: Text(context.lang.lowTreatmentRelationDetach),
                onPressed: busy || saving.value ? null : () => save(null),
              ),
          ],
        ),
      ],
    );
  }
}
