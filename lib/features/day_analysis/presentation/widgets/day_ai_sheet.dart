import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../core/llm/local_llm_client.dart';
import '../../data/providers/accepted_day_ai_provider.dart';
import '../../data/providers/day_summary_provider.dart';
import '../../domain/models/day_analysis_invalid_response.dart';
import '../../domain/models/day_dml_document.dart';
import '../controllers/day_ai_controller.dart';
import '../controllers/day_analysis_input_controller.dart';
import 'day_ai_actions.dart';
import 'day_ai_error_details_button.dart';
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
    final saved = ref.watch(acceptedDayAiProvider(date));
    final stored = saved.asData?.value;
    final input = stored != null
        ? AsyncData<DayDmlDocument?>(stored.analysis.document)
        : saved.isLoading || saved.hasError
        ? const AsyncLoading<DayDmlDocument?>()
        : ref.watch(dayDmlProvider(date));
    final draft = analysis.draft;
    final displayed = draft ?? stored?.analysis;
    final error = analysis.error;
    final rawResponse = error is DayAnalysisInvalidResponse
        ? error.response
        : displayed?.rawResponse;
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
                if (ready && !saved.hasError)
                  DayAiInputButton(
                    document: draft == null ? input : AsyncData(draft.document),
                    onRetry: () =>
                        ref.read(dayDmlProvider(date).notifier).retry(),
                    language: displayed?.result.language ?? request.language,
                    exactPrompt: displayed?.prompt,
                    isHistoricalInput: displayed != null,
                  ),
                if (rawResponse != null && !analysis.isGenerating)
                  TextButton.icon(
                    icon: const Icon(Icons.data_object),
                    label: Text(lang.dayAiShowResponse),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) =>
                          DayAiTextDialog(text: rawResponse, isResponse: true),
                    ),
                  ),
                if (saved.isLoading) const LinearProgressIndicator(),
                if (saved.hasError)
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(acceptedDayAiProvider(date)),
                    child: Text(lang.dayAiLoadFailed),
                  ),
                if (analysis.saveError != null) Text(lang.dayAiSaveFailed),
                if (error is LlmRequestException)
                  DayAiErrorDetailsButton(error: error),
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
                else if (analysis.isGenerating) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(lang.dayAiGenerating),
                ] else if (analysis.error != null)
                  Text(dayAiErrorMessage(lang, analysis.error)),
                if (ready && displayed != null) ...[
                  Text(draft != null ? lang.dayAiPreview : lang.dayAiSaved),
                  const SizedBox(height: 12),
                  DayAiResult(
                    result: displayed.result,
                    meals: displayed.document.meals,
                  ),
                ] else if (ready &&
                    !analysis.isGenerating &&
                    analysis.error == null &&
                    !saved.isLoading &&
                    !saved.hasError)
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
                child: DayAiActions(
                  request: request,
                  draft: draft,
                  hasSaved: stored != null,
                  hasAnalysis: displayed != null,
                  disabled:
                      analysis.isGenerating ||
                      analysis.isSaving ||
                      saved.isLoading ||
                      saved.hasError,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
