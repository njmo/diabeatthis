import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';

import '../../l10n/language.dart';
import '../../meal/meal_completion_timing.dart';

class MealCompletionTimeSection extends HookWidget {
  const MealCompletionTimeSection({
    super.key,
    required this.timing,
    required this.now,
    required this.editing,
    required this.endedAt,
    required this.onEditingChanged,
    required this.onEndedAtChanged,
    this.enabled = true,
  });

  final MealCompletionTiming timing;
  final DateTime now;
  final bool editing;
  final DateTime? endedAt;
  final ValueChanged<bool> onEditingChanged;
  final ValueChanged<DateTime?> onEndedAtChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final start = timing.startedAt;
    final controller = useTextEditingController();
    final format = DateFormat('d MMM HH:mm', lang.localeName);
    useEffect(() {
      if (!editing) {
        controller.clear();
      } else if (start != null && endedAt != null) {
        final value = endedAt!.difference(start).inMinutes.toString();
        if (controller.text != value) controller.text = value;
      }
      return null;
    }, [endedAt, start, editing]);
    if (!editing) {
      return CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: false,
        title: Text(lang.mealCompletionEarlier),
        subtitle: endedAt == null ? null : Text(format.format(endedAt!)),
        onChanged: enabled ? (_) => onEditingChanged(true) : null,
      );
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              lang.mealEatingFinishedEarlier,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              start == null
                  ? lang.mealCompletionMissingStart
                  : timing.isAddOn
                  ? lang.mealCompletionAddOnStartedAt(format.format(start))
                  : lang.mealCompletionStartedAt(format.format(start)),
            ),
            const SizedBox(height: 12),
            if (start != null)
              TextField(
                controller: controller,
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(),
                decoration: InputDecoration(
                  labelText: lang.mealCompletionDuration,
                ),
                onChanged: (text) {
                  final minutes = int.tryParse(text);
                  onEndedAtChanged(
                    minutes == null || minutes <= 0
                        ? null
                        : start.add(Duration(minutes: minutes)),
                  );
                },
              )
            else
              OutlinedButton.icon(
                onPressed: enabled ? () => selectEnd(context) : null,
                icon: const Icon(Icons.schedule),
                label: Text(lang.mealCompletionEndTime),
              ),
            const SizedBox(height: 12),
            Text(
              start == null
                  ? lang.mealCompletionEndTime
                  : lang.mealCompletionCalculatedEnd,
            ),
            Text(
              endedAt == null ? '—' : format.format(endedAt!),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (endedAt != null && !timing.isValidEnd(endedAt, now))
              Text(
                endedAt!.isAfter(now)
                    ? lang.mealCompletionFutureTime
                    : lang.mealCompletionInvalidTime,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: enabled
                    ? () {
                        controller.clear();
                        onEndedAtChanged(clock.now());
                        onEditingChanged(false);
                      }
                    : null,
                child: Text(lang.mealEatingFinishedNow),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> selectEnd(BuildContext context) async {
    final now = clock.now();
    final initial = endedAt ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: timing.startedAt ?? DateTime(2000),
      lastDate: now,
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time != null) {
      onEndedAtChanged(
        DateTime(date.year, date.month, date.day, time.hour, time.minute),
      );
    }
  }
}
