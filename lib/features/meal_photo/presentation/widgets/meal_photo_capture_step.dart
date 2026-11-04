import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/form_task_timeline_item.dart';
import '../../domain/models/meal_photo_input.dart';
import '../models/meal_photo_capture_task.dart';
import 'meal_photo_evidence_input.dart';

class MealPhotoCaptureStep extends HookWidget {
  const MealPhotoCaptureStep({
    super.key,
    required this.capturePhoto,
    required this.onGenerate,
    this.categoryField,
    this.categorySelected = true,
    this.categorySummary,
    this.needsClarification = false,
  });
  final Future<String?> Function(BuildContext context, bool menu) capturePhoto;
  final ValueChanged<MealPhotoInput> onGenerate;
  final Widget? categoryField;
  final bool categorySelected;
  final String? categorySummary;
  final bool needsClarification;

  @override
  Widget build(BuildContext context) {
    final plate = useState<String?>(null);
    final menu = useState<String?>(null);
    final busy = useState(false);
    final description = useTextEditingController();
    useListenable(description);
    final selectedTask = useState<MealPhotoCaptureTask?>(null);
    useEffect(() {
      if (needsClarification) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            selectedTask.value = MealPhotoCaptureTask.evidence;
          }
        });
      }
      return null;
    }, [needsClarification]);
    final input = MealPhotoInput(
      mealPhotoPath: plate.value ?? '',
      menuPhotoPath: menu.value,
      description: description.text,
    );
    final hasEvidence = input.hasCompositionEvidence;
    final requiredTask = categoryField != null && !categorySelected
        ? MealPhotoCaptureTask.category
        : plate.value == null
        ? MealPhotoCaptureTask.plate
        : null;
    final active = selectedTask.value ?? requiredTask;
    void toggle(MealPhotoCaptureTask task) {
      if (task == requiredTask && selectedTask.value == null) return;
      selectedTask.value = selectedTask.value == task ? null : task;
    }

    Future<void> capture(bool isMenu) async {
      if (busy.value) return;
      busy.value = true;
      try {
        final path = await capturePhoto(context, isMenu);
        if (context.mounted && path != null) {
          if (isMenu) {
            menu.value = path;
          } else {
            plate.value = path;
          }
          selectedTask.value = null;
        }
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (categoryField != null)
          FormTaskTimelineItem(
            title: context.lang.mealCategoryLabel,
            subtitle: categorySummary,
            completed: categorySelected,
            active: active == MealPhotoCaptureTask.category,
            onTap: () => toggle(MealPhotoCaptureTask.category),
            child: categoryField!,
          ),
        FormTaskTimelineItem(
          title: context.lang.mealPhotoStepPhoto,
          completed: plate.value != null,
          active: active == MealPhotoCaptureTask.plate,
          onTap: () => toggle(MealPhotoCaptureTask.plate),
          child: OutlinedButton.icon(
            onPressed: busy.value ? null : () => capture(false),
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text(context.lang.mealPhotoPlate),
          ),
        ),
        FormTaskTimelineItem(
          title: context.lang.mealPhotoCompositionOptional,
          optional: true,
          subtitle: description.text.trim().isNotEmpty
              ? description.text.trim()
              : menu.value != null
              ? context.lang.mealPhotoCompositionMenuReady
              : null,
          completed: hasEvidence,
          active: active == MealPhotoCaptureTask.evidence,
          isLast: true,
          onTap: () => toggle(MealPhotoCaptureTask.evidence),
          child: MealPhotoEvidenceInput(
            description: description,
            menuPhotoSelected: menu.value != null,
            busy: busy.value,
            onMenuPhoto: () => capture(true),
            onTextChanged: (_) =>
                selectedTask.value = MealPhotoCaptureTask.evidence,
          ),
        ),
        FilledButton(
          onPressed: busy.value || plate.value == null || !categorySelected
              ? null
              : () => onGenerate(input),
          child: Text(context.lang.mealPhotoGenerate),
        ),
      ],
    );
  }
}
