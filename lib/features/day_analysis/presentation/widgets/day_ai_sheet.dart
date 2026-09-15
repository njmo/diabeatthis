import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../data/providers/day_summary_provider.dart';
import '../../domain/models/day_analysis_invalid_response.dart';
import '../controllers/day_ai_controller.dart';
import '../controllers/day_analysis_input_controller.dart';
import 'day_ai_error_message.dart';
import 'day_ai_input_button.dart';
import 'day_ai_result.dart';
import 'day_ai_text_dialog.dart';

class DayAiSheet extends ConsumerWidget {
  final DateTime date;
  const DayAiSheet({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.lang;
    final request = (
      date: date,
      language: Localizations.localeOf(context).languageCode,
    );
    final analysis = ref.watch(dayAiControllerProvider(request));
    final archive = ref.watch(acceptedDaySummaryProvider(date));
    final input = ref.watch(dayDmlProvider(date));
    final draft = analysis.asData?.value;
    final error = analysis.error;
    final rawResponse = error is DayAnalysisInvalidResponse
        ? error.response
        : draft?.rawResponse;
    final ready = archive.asData?.value != null;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.dayAiTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(DateFormat.yMMMd(lang.localeName).format(date)),
                  ],
                ),
              ),
              IconButton(
                tooltip: lang.dayAiClose,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (ready)
                  DayAiInputButton(
                    document: input,
                    onRetry: () =>
                        ref.read(dayDmlProvider(date).notifier).retry(),
                    language: request.language,
                  ),
                if (rawResponse != null && !analysis.isLoading)
                  TextButton.icon(
                    icon: const Icon(Icons.data_object),
                    label: Text(lang.dayAiShowResponse),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) =>
                          DayAiTextDialog(text: rawResponse, isResponse: true),
                    ),
                  ),
                if (archive.isLoading)
                  const LinearProgressIndicator()
                else if (archive.hasError)
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(acceptedDaySummaryProvider(date)),
                    child: Text(lang.dayReviewArchiveFailed),
                  )
                else if (!ready)
                  Text(lang.dayAiNeedsAcceptedDay)
                else if (analysis.isLoading) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(lang.dayAiGenerating),
                ] else if (analysis.hasError)
                  Text(dayAiErrorMessage(lang, analysis.error))
                else if (draft != null) ...[
                  Text(lang.dayAiPreview),
                  const SizedBox(height: 12),
                  DayAiResult(
                    result: draft.result,
                    meals: draft.document.meals,
                  ),
                ] else
                  Text(lang.dayAiIntro),
              ],
            ),
          ),
        ),
        if (ready)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: analysis.isLoading
                      ? null
                      : () => ref
                            .read(dayAiControllerProvider(request).notifier)
                            .generate(),
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(
                    draft == null ? lang.dayAiGenerate : lang.dayAiRegenerate,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
