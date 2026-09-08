import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/bottom_sheet_step_header.dart';
import '../../../../common/widgets/date_time_picker.dart';
import '../../../../common/widgets/keyboard_aware_bottom_sheet.dart';
import '../../../../core/data_sources/stress_events/stress_event_repository.dart';
import '../../../../core/domain/model/stress_event.dart';
import '../../../../core/domain/model/stress_level.dart';
import '../../../../core/logger/logger.dart';
import 'manual_event_time_field.dart';
import 'stress_event_fields.dart';

Future<void> showManualEventSheet(BuildContext context) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const ManualEventSheet(),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.lang.manualEventSaved)));
  }
}

class ManualEventSheet extends HookConsumerWidget with Logging {
  const ManualEventSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = clock.now();
    final occurredAt = useState(
      DateTime(now.year, now.month, now.day, now.hour, now.minute),
    );
    final notes = useTextEditingController();
    final saving = useState(false);
    final stressLevel = useState(StressLevel.moderate);
    final endedAt = useState<DateTime?>(null);
    final error = useState<String?>(null);

    return PopScope(
      canPop: !saving.value,
      child: KeyboardAwareBottomSheet(
        header: BottomSheetStepHeader(title: context.lang.manualEventStress),
        body: AbsorbPointer(
          absorbing: saving.value,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ManualEventTimeField(
                label: context.lang.manualEventStressStart,
                value: occurredAt.value,
                onChanged: (value) {
                  occurredAt.value = value;
                  if (endedAt.value != null) {
                    endedAt.value = endTimeForStart(
                      value,
                      TimeOfDay.fromDateTime(endedAt.value!),
                    );
                  }
                  error.value = null;
                },
              ),
              StressEventFields(
                level: stressLevel.value,
                startedAt: occurredAt.value,
                endedAt: endedAt.value,
                onLevelChanged: (value) => stressLevel.value = value,
                onEndChanged: (value) {
                  endedAt.value = value;
                  error.value = null;
                },
              ),
              TextFormField(
                controller: notes,
                decoration: InputDecoration(
                  labelText: context.lang.manualEventNotes,
                ),
                maxLines: 3,
              ),
              if (error.value != null)
                Text(
                  error.value!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: FilledButton(
          onPressed: saving.value
              ? null
              : () async {
                  if (occurredAt.value.isAfter(clock.now())) {
                    error.value = context.lang.manualEventFutureTime;
                    return;
                  }
                  if (endedAt.value != null &&
                      !endedAt.value!.isAfter(occurredAt.value)) {
                    error.value = context.lang.manualEventStressIntervalInvalid;
                    return;
                  }
                  saving.value = true;
                  error.value = null;
                  try {
                    await ref
                        .read(stressEventRepositoryProvider)
                        .save(
                          StressEvent(
                            source: 'manual',
                            stressLevel: stressLevel.value,
                            endedAt: endedAt.value,
                            notes: notes.text.trim().isEmpty
                                ? null
                                : notes.text.trim(),
                            occurredAt: occurredAt.value,
                          ),
                        );
                    if (context.mounted) {
                      saving.value = false;
                      Navigator.of(context).pop(true);
                    }
                  } catch (exception, stackTrace) {
                    logE(
                      'Failed to save stress event',
                      error: exception,
                      stackTrace: stackTrace,
                    );
                    if (context.mounted) {
                      error.value = context.lang.manualEventSaveFailed;
                      saving.value = false;
                    }
                  }
                },
          child: Text(
            saving.value
                ? context.lang.manualEventSaving
                : context.lang.manualEventSave,
          ),
        ),
      ),
    );
  }
}
