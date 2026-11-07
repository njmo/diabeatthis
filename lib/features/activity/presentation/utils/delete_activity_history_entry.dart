import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/activity/activity_session_state.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/delete_confirmation_dialog.dart';
import '../../common/controllers/activity_actions_controller.dart';
import '../../data/models/activity_log_summary_data.dart';

Future<void> deleteActivityHistoryEntry(
  BuildContext context,
  WidgetRef ref,
  ActivityLogSummaryData entry,
) async {
  final local = entry.startedAt.toLocal();
  final time =
      '${MaterialLocalizations.of(context).formatCompactDate(local)} · '
      '${TimeOfDay.fromDateTime(local).format(context)}';
  final lang = context.lang;
  final message = lang.activityHistoryDeleteMessage(entry.activityName, time);
  bool activeNow() =>
      activitySessionState(
        startedAt: entry.startedAt,
        endedAt: entry.endedAt,
      ) ==
      ActivitySessionState.active;
  Future<bool> confirm(bool active) => showDeleteConfirmationDialog(
    context,
    title: lang.activityHistoryDeleteTitle,
    message: active
        ? '$message\n\n${lang.activityHistoryDeleteActiveMessage}'
        : message,
  );
  final initiallyActive = activeNow();
  if (!await confirm(initiallyActive) || !context.mounted) return;
  // A reservation may have started while its confirmation dialog was open.
  if (!initiallyActive && activeNow()) {
    if (!await confirm(true) || !context.mounted) return;
  }
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(activityActionsControllerProvider.notifier).delete(entry.id);
    // The row can be unmounted by its database stream before this completes.
    if (messenger.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(lang.activityHistoryDeleteSuccess)),
      );
    }
  } catch (_) {
    if (messenger.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(lang.activityHistoryDeleteFailed)),
      );
    }
  }
}
