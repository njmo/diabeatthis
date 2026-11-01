import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/models/timeline_relation.dart';
import '../../../../common/widgets/timeline_relation_picker.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../data/repositories/low_treatment_relation_repository.dart';
import 'low_treatment_relation_card.dart';

class LowTreatmentRelationEditor extends HookConsumerWidget {
  const LowTreatmentRelationEditor({
    super.key,
    required this.occurredAt,
    required this.onChanged,
    this.mealId,
    this.relatedMealId,
    this.relatedActivityLogId,
    this.busy = false,
    this.automatic,
  });
  final DateTime occurredAt;
  final int? mealId;
  final int? relatedMealId;
  final int? relatedActivityLogId;
  final bool busy;
  final bool? automatic;
  final Future<void> Function(TimelineRelation?) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final repository = LowTreatmentRelationRepository(db);
    final saving = useState(false);
    final retry = useState(0);
    final future = useMemoized(
      () => repository.resolve(
        mealId: relatedMealId,
        activityLogId: relatedActivityLogId,
      ),
      [db, relatedMealId, relatedActivityLogId, retry.value],
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

    Future<void> choose(TimelineRelationKind kind) async {
      final selected = await showModalBottomSheet<TimelineRelation>(
        context: context,
        isScrollControlled: true,
        builder: (_) => TimelineRelationPicker(
          occurredAt: occurredAt,
          initialKind: kind,
          load: (day) =>
              repository.load(day, occurredAt, excludeMealId: mealId),
        ),
      );
      if (selected != null && context.mounted) await save(selected);
    }

    final disabled = busy || saving.value;
    final relation = current.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!linked)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: disabled
                  ? null
                  : () => choose(TimelineRelationKind.activity),
              icon: const Icon(Icons.link_rounded, size: 18),
              label: Text(context.lang.lowTreatmentLinkAction),
            ),
          ),
        if (current.connectionState != ConnectionState.done && linked)
          const LinearProgressIndicator(),
        if (current.hasError)
          TextButton(
            onPressed: () => retry.value++,
            child: Text(context.lang.lowTreatmentRelationRetry),
          ),
        if (relation != null) ...[
          LowTreatmentRelationCard(
            relation: relation,
            automatic: automatic,
            onChange: disabled ? null : () => choose(relation.kind),
            onDetach: disabled ? null : () => save(null),
          ),
        ] else if (linked)
          TextButton.icon(
            onPressed: disabled ? null : () => save(null),
            icon: const Icon(Icons.link_off),
            label: Text(context.lang.lowTreatmentRelationDetach),
          ),
      ],
    );
  }
}
