import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../controllers/activity_summary_controller.dart';
import 'activity_summary_dialog.dart';

class ActivitySummaryAction extends ConsumerWidget {
  const ActivitySummaryAction({
    super.key,
    required this.activityLogId,
    required this.summarized,
    this.intensity,
    this.notes,
    this.compact = false,
    this.emphasized = false,
  });
  final int activityLogId;
  final bool summarized;
  final String? intensity;
  final String? notes;
  final bool compact;
  final bool emphasized;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = compact
        ? TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle: Theme.of(context).textTheme.labelMedium,
          )
        : null;
    final label = Text(
      summarized
          ? context.lang.activitySummaryEdit
          : context.lang.activitySummaryAction,
    );
    final controller = ref.watch(activitySummaryControllerProvider);
    Future<void> onPressed() async {
      final notifier = ref.read(activitySummaryControllerProvider.notifier);
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ActivitySummaryDialog(
          intensity: intensity,
          notes: notes,
          onSave: (intensity, notes) => notifier.save(
            activityLogId: activityLogId,
            intensity: intensity,
            notes: notes,
          ),
        ),
      );
      if (saved == true && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.lang.activitySaved)));
      }
    }

    if (emphasized) {
      return FilledButton.tonal(
        style: style,
        onPressed: controller.isLoading ? null : onPressed,
        child: label,
      );
    }
    return TextButton.icon(
      style: style,
      icon: compact
          ? null
          : Icon(summarized ? Icons.edit_outlined : Icons.rate_review_outlined),
      label: label,
      onPressed: controller.isLoading ? null : onPressed,
    );
  }
}
