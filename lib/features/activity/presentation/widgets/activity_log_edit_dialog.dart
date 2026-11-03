import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../common/l10n/language.dart';
import '../../common/widgets/activity_intensity_field.dart';
import 'activity_log_time_edit_dialog.dart';

class ActivityLogEditDialog extends HookWidget {
  const ActivityLogEditDialog({
    super.key,
    required this.startedAt,
    required this.endedAt,
    this.intensity,
    this.notes,
    required this.onSave,
  });
  final DateTime startedAt;
  final DateTime endedAt;
  final String? intensity;
  final String? notes;
  final Future<void> Function(
    DateTime start,
    DateTime end,
    String? intensity,
    String notes,
  )
  onSave;

  @override
  Widget build(BuildContext context) {
    final selected = useState(intensity);
    final controller = useTextEditingController(text: notes);
    return ActivityLogTimeEditDialog(
      title: context.lang.activityLogEditTitle,
      startedAt: startedAt,
      endedAt: endedAt,
      onSave: (start, end) =>
          onSave(start, end, selected.value, controller.text),
      additionalFieldsBuilder: (saving) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ActivityIntensityField(
            value: selected.value,
            onChanged: saving ? null : (value) => selected.value = value,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            enabled: !saving,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: context.lang.activityNotesLabel,
            ),
          ),
        ],
      ),
    );
  }
}
