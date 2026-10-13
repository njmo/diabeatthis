import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../controllers/meal_ai_controller.dart';

class MealAiActions extends ConsumerWidget {
  final MealAiRequest request;
  final bool hasSaved;
  final bool canGenerate;
  final bool canSave;
  const MealAiActions({
    super.key,
    required this.request,
    required this.hasSaved,
    required this.canGenerate,
    required this.canSave,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mealAiControllerProvider(request));
    final controller = ref.read(mealAiControllerProvider(request).notifier);
    final lang = context.lang;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        if (state.draft != null) ...[
          TextButton(
            onPressed: state.busy ? null : controller.discard,
            child: Text(lang.dayAiDiscard),
          ),
          FilledButton(
            onPressed: state.busy || !canSave ? null : controller.accept,
            child: Text(hasSaved ? lang.dayAiReplace : lang.dayAiAccept),
          ),
        ],
        OutlinedButton.icon(
          onPressed: state.busy || !canGenerate ? null : controller.generate,
          icon: const Icon(Icons.auto_awesome),
          label: Text(
            state.draft != null || hasSaved
                ? lang.dayAiRegenerate
                : lang.mealAiGenerate,
          ),
        ),
      ],
    );
  }
}
