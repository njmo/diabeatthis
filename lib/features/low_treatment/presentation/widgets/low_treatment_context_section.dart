import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/models/timeline_relation.dart';
import '../../../../common/widgets/section_surface.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../data/repositories/low_treatment_relation_repository.dart';
import '../controllers/low_treatment_context_controller.dart';
import '../formatters/low_treatment_context_formatters.dart';
import 'low_treatment_context_editor.dart';
import 'low_treatment_context_summary_row.dart';

class LowTreatmentContextSection extends HookConsumerWidget {
  const LowTreatmentContextSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lowTreatmentContextControllerProvider).requireValue;
    final db = ref.watch(databaseProvider);
    final future = useMemoized(
      () => LowTreatmentRelationRepository(db).resolve(
        mealId: state.contextDraft.relatedMealId,
        activityLogId: state.contextDraft.relatedActivityLogId,
      ),
      [
        db,
        state.contextDraft.relatedMealId,
        state.contextDraft.relatedActivityLogId,
      ],
    );
    final relation = useFuture(future);
    final theme = Theme.of(context);
    final linked = relation.data;
    final container = ProviderScope.containerOf(context);
    void edit() {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => UncontrolledProviderScope(
          container: container,
          child: const LowTreatmentContextEditor(),
        ),
      );
    }

    final relationText = relation.hasError
        ? context.lang.lowTreatmentRelationRetry
        : relation.connectionState != ConnectionState.done
        ? '…'
        : linked == null
        ? context.lang.lowTreatmentRelationDetach
        : '${linked.name} · ${DateFormat('HH:mm').format(linked.at)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.lang.lowTreatmentContextSection,
                style: theme.textTheme.titleSmall,
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: state.isSaving ? null : edit,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(context.lang.ingredientEditAction),
            ),
          ],
        ),
        SectionSurface(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              LowTreatmentContextSummaryRow(
                icon: Icons.label_outline_rounded,
                label: context.lang.lowTreatmentReasonShort,
                value: lowTreatmentReasonLabel(state.reason, context.lang),
                automatic: state.reasonAutoSelected,
              ),
              const Divider(height: 16),
              LowTreatmentContextSummaryRow(
                icon: linked?.kind == TimelineRelationKind.activity
                    ? Icons.directions_run_rounded
                    : Icons.link_rounded,
                label: context.lang.lowTreatmentRelationTitle,
                value: relationText,
                automatic: linked != null && state.relatedAutoAttachEnabled,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
