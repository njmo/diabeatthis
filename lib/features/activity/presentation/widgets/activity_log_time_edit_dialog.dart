import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../common/l10n/language.dart';
import 'activity_log_time_field.dart';

class ActivityLogTimeEditDialog extends HookWidget {
  const ActivityLogTimeEditDialog({
    super.key,
    required this.startedAt,
    required this.endedAt,
    required this.onSave,
  });
  final DateTime startedAt;
  final DateTime endedAt;
  final Future<void> Function(DateTime startedAt, DateTime endedAt) onSave;

  @override
  Widget build(BuildContext context) {
    final start = useState(startedAt);
    final end = useState(endedAt);
    final saving = useState(false);
    final invalid = useState(false);
    final failed = useState(false);
    return PopScope(
      canPop: !saving.value,
      child: AlertDialog(
        title: Text(context.lang.activityLogEditTimes),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ActivityLogTimeField(
                key: const ValueKey('activity_log_start'),
                label: context.lang.activityStartLabel,
                value: start.value,
                enabled: !saving.value,
                onChanged: (value) {
                  start.value = value;
                  invalid.value = false;
                  failed.value = false;
                },
              ),
              const SizedBox(height: 12),
              ActivityLogTimeField(
                key: const ValueKey('activity_log_end'),
                label: context.lang.activityEndLabel,
                value: end.value,
                enabled: !saving.value,
                onChanged: (value) {
                  end.value = value;
                  invalid.value = false;
                  failed.value = false;
                },
              ),
              if (invalid.value || failed.value)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    invalid.value
                        ? context.lang.activityLogTimeInvalid
                        : context.lang.activityLogTimeSaveFailed,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving.value ? null : () => Navigator.of(context).pop(),
            child: Text(context.lang.settingsCancel),
          ),
          FilledButton(
            onPressed: saving.value
                ? null
                : () async {
                    if (saving.value) return;
                    if (!end.value.isAfter(start.value) ||
                        end.value.isAfter(clock.now())) {
                      invalid.value = true;
                      return;
                    }
                    saving.value = true;
                    failed.value = false;
                    try {
                      await onSave(start.value, end.value);
                      if (context.mounted) Navigator.of(context).pop(true);
                    } catch (_) {
                      if (context.mounted) failed.value = true;
                    } finally {
                      if (context.mounted) saving.value = false;
                    }
                  },
            child: saving.value
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.lang.settingsSave),
          ),
        ],
      ),
    );
  }
}
