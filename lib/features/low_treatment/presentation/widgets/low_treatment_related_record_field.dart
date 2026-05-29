import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/models/low_treatment_related_record.dart';
import '../../data/models/low_treatment_sheet_state.dart';
import '../controllers/low_treatment_context_controller.dart';

class LowTreatmentRelatedRecordField extends ConsumerWidget {
  const LowTreatmentRelatedRecordField({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheetState = ref.watch(
      lowTreatmentContextControllerProvider.select((state) => state.value),
    );
    final record = sheetState?.selectedRelatedRecord;
    if (sheetState == null || record == null) {
      return const SizedBox.shrink();
    }
    final controller = ref.read(lowTreatmentContextControllerProvider.notifier);
    final onSwitch = _switchRelatedContextAction(sheetState, controller);
    final onDetach = sheetState.isSaving
        ? null
        : controller.detachRelatedContext;

    final config = record.map(
      meal: (record) => (
        labelText: 'Powiązany posiłek',
        title: record.name,
        actionIcon: Icons.directions_run,
        actionTooltip: 'Podepnij aktywność',
        detachTooltip: 'Odepnij posiłek',
      ),
      activity: (record) => (
        labelText: 'Powiązana aktywność',
        title: record.name,
        actionIcon: Icons.restaurant,
        actionTooltip: 'Podepnij posiłek',
        detachTooltip: 'Odepnij aktywność',
      ),
    );
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: config.labelText,
          border: const OutlineInputBorder(),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: config.actionTooltip,
                onPressed: onSwitch,
                icon: Icon(config.actionIcon),
              ),
              IconButton(
                tooltip: config.detachTooltip,
                onPressed: onDetach,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        child: Text(
          config.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }

  VoidCallback? _switchRelatedContextAction(
    LowTreatmentSheetState sheetState,
    LowTreatmentContextController controller,
  ) {
    if (sheetState.isSaving) {
      return null;
    }

    final record = sheetState.selectedRelatedRecord;
    if (record == null) {
      return null;
    }

    return record.map(
      activity: (_) => sheetState.canSwitchToRelatedMeal
          ? controller.switchRelatedContext
          : null,
      meal: (_) => sheetState.canSwitchToRelatedActivity
          ? controller.switchRelatedContext
          : null,
    );
  }
}
