import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../data/models/activity_log_details_data.dart';
import '../controllers/activity_log_details_controller.dart';
import 'activity_log_time_edit_dialog.dart';

class ActivityLogEditTimeButton extends ConsumerWidget {
  const ActivityLogEditTimeButton({super.key, required this.log});
  final ActivityLogDetailsData log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (log.endedAt == null) return const SizedBox.shrink();
    return TextButton.icon(
      icon: const Icon(Icons.edit_outlined),
      label: Text(context.lang.activityLogEditTimes),
      onPressed: () async {
        final saved = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => ActivityLogTimeEditDialog(
            startedAt: log.startedAt,
            endedAt: log.endedAt!,
            onSave: (start, end) => ref
                .read(activityLogDetailsControllerProvider(log.id).notifier)
                .updateCompletedTimes(
                  original: log,
                  startedAt: start,
                  endedAt: end,
                ),
          ),
        );
        if (saved == true && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.lang.activitySaved)));
        }
      },
    );
  }
}
