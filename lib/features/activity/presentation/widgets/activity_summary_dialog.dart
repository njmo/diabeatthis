import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../common/l10n/language.dart';
import '../../common/widgets/activity_intensity_field.dart';

class ActivitySummaryDialog extends HookWidget {
  const ActivitySummaryDialog({
    super.key,
    this.intensity,
    this.notes,
    required this.onSave,
  });

  final String? intensity;
  final String? notes;
  final Future<void> Function(String? intensity, String notes) onSave;

  @override
  Widget build(BuildContext context) {
    final selected = useState(intensity);
    final controller = useTextEditingController(text: notes);
    final saving = useState(false);
    final failed = useState(false);
    return PopScope(
      canPop: !saving.value,
      child: AlertDialog(
        title: Text(context.lang.activitySummaryTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ActivityIntensityField(
                value: selected.value,
                onChanged: saving.value
                    ? null
                    : (value) => selected.value = value,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                enabled: !saving.value,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: context.lang.activityNotesLabel,
                ),
              ),
              if (failed.value)
                Text(
                  context.lang.activitySummarySaveFailed,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                    saving.value = true;
                    failed.value = false;
                    try {
                      await onSave(selected.value, controller.text);
                      if (context.mounted) Navigator.of(context).pop(true);
                    } catch (_) {
                      if (context.mounted) failed.value = true;
                    } finally {
                      if (context.mounted) saving.value = false;
                    }
                  },
            child: Text(context.lang.settingsSave),
          ),
        ],
      ),
    );
  }
}
