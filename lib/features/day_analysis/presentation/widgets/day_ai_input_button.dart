import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../data/prompts/day_analysis_prompt.dart';
import '../../domain/models/day_dml_document.dart';
import 'day_ai_text_dialog.dart';

class DayAiInputButton extends StatelessWidget {
  final AsyncValue<DayDmlDocument?> document;
  final String language;
  final String? exactPrompt;
  final bool isHistoricalInput;
  final VoidCallback onRetry;
  const DayAiInputButton({
    super.key,
    required this.document,
    required this.language,
    this.exactPrompt,
    this.isHistoricalInput = false,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (document.isLoading) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text(context.lang.dayAiPreparingInput),
      );
    }
    if (document.hasError) {
      return TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: Text(context.lang.dayReviewBuildFailed),
      );
    }
    final value = document.asData?.value;
    return TextButton.icon(
      icon: const Icon(Icons.subject),
      label: Text(context.lang.dayAiShowInput),
      onPressed: value == null
          ? null
          : () => showDialog<void>(
              context: context,
              builder: (_) => DayAiTextDialog(
                text:
                    exactPrompt ??
                    (isHistoricalInput
                        ? '${context.lang.dayAiOriginalPromptUnavailable}\n\n${value.text}'
                        : buildDayAnalysisPrompt(value, language)),
              ),
            ),
    );
  }
}
