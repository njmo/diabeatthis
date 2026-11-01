import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/keyboard_aware_bottom_sheet.dart';
import '../controllers/low_treatment_context_controller.dart';
import 'low_treatment_reason_selector.dart';
import 'low_treatment_relation_editor.dart';

class LowTreatmentContextEditor extends ConsumerWidget {
  const LowTreatmentContextEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lowTreatmentContextControllerProvider).requireValue;
    final controller = ref.read(lowTreatmentContextControllerProvider.notifier);
    return KeyboardAwareBottomSheet(
      header: Row(
        children: [
          Expanded(
            child: Text(
              context.lang.lowTreatmentContextSection,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: context.lang.commonCloseTooltip,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          LowTreatmentReasonSelector(
            value: state.reason,
            hasAapsSuggestion: state.hasAapsSuggestion,
            onChanged: controller.setReason,
          ),
          const SizedBox(height: 16),
          Text(
            context.lang.lowTreatmentRelationTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          LowTreatmentRelationEditor(
            occurredAt: state.contextDraft.meal.plannedAt,
            relatedMealId: state.contextDraft.relatedMealId,
            relatedActivityLogId: state.contextDraft.relatedActivityLogId,
            automatic: state.relatedAutoAttachEnabled,
            busy: state.isSaving,
            onChanged: (relation) async =>
                controller.setRelatedRecord(relation),
          ),
        ],
      ),
      actions: FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.lang.commonDone),
      ),
    );
  }
}
