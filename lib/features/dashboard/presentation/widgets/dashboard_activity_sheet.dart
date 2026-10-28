import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/date_time_picker.dart';
import '../../../../common/widgets/duration_minutes_field.dart';
import '../../../../common/widgets/keyboard_aware_bottom_sheet.dart';
import '../../../activity/data/drafts/activity_draft.dart';
import '../../../activity/data/drafts/activity_entry_action.dart';
import '../../../activity/presentation/widgets/activity_picker_sheet.dart';
import '../../../activity/presentation/widgets/selected_activity_card.dart';

export '../../../activity/data/drafts/activity_entry_action.dart';

enum ActivityEntryMode { now, historical, planned }

class DashboardActivitySheet extends HookConsumerWidget {
  const DashboardActivitySheet({
    super.key,
    this.initialActivity,
    this.initialMode,
    this.initialStart,
    this.initialDuration,
    this.lockMode = false,
  });
  final ActivityDraft? initialActivity;
  final ActivityEntryMode? initialMode;
  final DateTime? initialStart;
  final int? initialDuration;
  final bool lockMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedActivity = useState<ActivityDraft?>(initialActivity);
    final mode = useState(initialMode ?? ActivityEntryMode.now);
    final startAt = useState(initialStart ?? clock.now());
    final duration = useTextEditingController(
      text:
          initialDuration?.toString() ??
          initialActivity?.durationMinutes?.toString() ??
          '',
    );
    useListenable(duration);
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final error = useState<String?>(null);
    final selected = selectedActivity.value;
    final history = mode.value == ActivityEntryMode.historical;
    final planned = mode.value == ActivityEntryMode.planned;
    final needsDuration = history || planned;
    final minutes = int.tryParse(duration.text);
    final end = minutes == null
        ? null
        : startAt.value.add(Duration(minutes: minutes));

    Future<void> pickActivity() async {
      final activity = await showActivityPickerSheet(context);
      if (!context.mounted || activity == null) return;
      selectedActivity.value = activity;
      duration.text = activity.durationMinutes?.toString() ?? '';
    }

    return KeyboardAwareBottomSheet(
      header: Row(
        children: [
          Expanded(
            child: Text(
              context.lang.activityAddOccurrence,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: context.lang.commonCloseTooltip,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (selected == null)
              OutlinedButton.icon(
                onPressed: pickActivity,
                icon: const Icon(Icons.search),
                label: Text(context.lang.activityPickTitle),
              )
            else
              SelectedActivityCard(
                activity: selected,
                onChange: !lockMode ? pickActivity : null,
              ),
            const SizedBox(height: 12),
            if (!lockMode)
              SegmentedButton<ActivityEntryMode>(
                segments: [
                  ButtonSegment(
                    value: ActivityEntryMode.now,
                    label: Text(context.lang.activityEntryNow),
                  ),
                  ButtonSegment(
                    value: ActivityEntryMode.historical,
                    label: Text(context.lang.activityEntryHistory),
                  ),
                  ButtonSegment(
                    value: ActivityEntryMode.planned,
                    label: Text(context.lang.activityEntryLater),
                  ),
                ],
                selected: {mode.value},
                onSelectionChanged: (value) {
                  mode.value = value.single;
                  if (value.single == ActivityEntryMode.historical &&
                      startAt.value.isAfter(clock.now())) {
                    startAt.value = clock.now().subtract(
                      Duration(minutes: minutes ?? 0),
                    );
                  }
                  error.value = null;
                },
              ),
            if (history || planned) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event),
                label: Text(
                  DateFormat.yMd(
                    context.lang.localeName,
                  ).add_Hm().format(startAt.value),
                ),
                onPressed: () async {
                  final picked = await showDateTimePicker(
                    context: context,
                    initialDate: startAt.value,
                    lastDate: history ? clock.now() : null,
                  );
                  if (picked != null) startAt.value = picked;
                },
              ),
              if (history)
                Wrap(
                  spacing: 8,
                  children: [0, 1]
                      .map(
                        (days) => ActionChip(
                          label: Text(
                            days == 0
                                ? context.lang.activityToday
                                : context.lang.activityYesterday,
                          ),
                          onPressed: () {
                            final now = clock.now();
                            startAt.value = DateTime(
                              now.year,
                              now.month,
                              now.day - days,
                              startAt.value.hour,
                              startAt.value.minute,
                            );
                          },
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 12),
              DurationMinutesField(controller: duration),
              if (history && end != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    context.lang.activityHistoryEnd(
                      DateFormat.yMd(
                        context.lang.localeName,
                      ).add_Hm().format(end),
                    ),
                  ),
                ),
            ],
            if (error.value != null)
              Text(
                error.value!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.lang.settingsCancel),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: selected == null
                  ? null
                  : () {
                      if (!formKey.currentState!.validate()) return;
                      if (history &&
                          (end == null ||
                              end.isAfter(clock.now()) ||
                              !end.isAfter(startAt.value))) {
                        error.value = context.lang.activityHistoryInvalid;
                        return;
                      }
                      if (planned && !startAt.value.isAfter(clock.now())) {
                        error.value = context.lang.activitySingleTimeInvalid;
                        return;
                      }
                      Navigator.of(context).pop(
                        DashboardActivityAction(
                          activity: selected,
                          startedAt: mode.value == ActivityEntryMode.now
                              ? clock.now()
                              : startAt.value,
                          isScheduled: planned,
                          endedAt: history ? end : null,
                          durationMinutes: needsDuration
                              ? minutes
                              : selected.durationMinutes,
                        ),
                      );
                    },
              child: Text(
                history
                    ? context.lang.activityHistorySave
                    : planned
                    ? context.lang.activitySingleSave
                    : context.lang.activityStartNow,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
