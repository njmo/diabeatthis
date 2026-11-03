import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/date_time_picker.dart';

/// A nullable value means "now", resolved only when the action is confirmed.
class ActivityStartTimeField extends StatelessWidget {
  const ActivityStartTimeField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.lang.dashboardActivityStartedAt,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text(context.lang.dashboardActivityStartNow),
              selected: selected == null,
              onSelected: (_) => onChanged(null),
            ),
            ActionChip(
              avatar: const Icon(Icons.schedule_rounded, size: 18),
              label: Text(
                selected == null
                    ? context.lang.dashboardActivityChooseStart
                    : TimeOfDay.fromDateTime(selected).format(context),
              ),
              onPressed: () async {
                final picked = await showTodayTimePicker(
                  context: context,
                  initialDate: selected ?? clock.now(),
                );
                if (picked == null || !context.mounted) return;
                if (picked.isAfter(clock.now())) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.lang.dashboardActivityStartInFuture,
                      ),
                    ),
                  );
                  return;
                }
                onChanged(picked);
              },
            ),
          ],
        ),
      ],
    );
  }
}
