import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import 'meal_completion_actions.dart';

class MealCompletionChoiceSheet extends StatelessWidget {
  const MealCompletionChoiceSheet({
    super.key,
    required this.mealName,
    required this.requiresBolus,
    required this.saving,
    required this.onAsPlanned,
    required this.onDifferent,
    this.onEarlier,
    this.onClose,
    this.error,
  });

  final String mealName;
  final bool requiresBolus;
  final bool saving;
  final VoidCallback onAsPlanned;
  final VoidCallback onDifferent;
  final VoidCallback? onEarlier;
  final VoidCallback? onClose;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return PopScope(
      canPop: !saving,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      lang.mealCompletionQuestion,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: lang.commonCloseTooltip,
                    onPressed: saving
                        ? null
                        : onClose ?? () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(mealName, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              MealCompletionActions(
                primaryLabel: lang.mealCompletionAsPlannedAction,
                primaryDescription: lang.mealCompletionAllHint,
                secondaryLabel: lang.mealCompletionAdjustedAction,
                secondaryDescription: lang.mealCompletionAdjustedHint,
                onPrimaryPressed: saving ? null : onAsPlanned,
                onSecondaryPressed: saving ? null : onDifferent,
              ),
              const SizedBox(height: 8),
              Text(
                requiresBolus
                    ? lang.mealCompletionSaveImmediatelyBeforeBolus
                    : lang.mealCompletionSaveImmediately,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (onEarlier != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: saving ? null : onEarlier,
                    icon: const Icon(Icons.history, size: 18),
                    label: Text(lang.mealEatingFinishedEarlier),
                  ),
                ),
              if (saving) ...[
                const SizedBox(height: 16),
                const Center(
                  child: SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
