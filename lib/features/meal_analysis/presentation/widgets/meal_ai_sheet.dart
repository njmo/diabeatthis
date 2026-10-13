import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../common/analysis/ai_request_error_message.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/ai_text_dialog.dart';
import '../../data/prompts/meal_ai_prompt.dart';
import '../../data/providers/meal_ai_provider.dart';
import '../../domain/models/meal_ai_invalid_response.dart';
import '../controllers/meal_ai_controller.dart';
import '../controllers/meal_ai_input_controller.dart';
import 'meal_ai_actions.dart';
import 'meal_ai_result_cards.dart';

class MealAiSheet extends ConsumerWidget {
  final int mealId;
  final String name;
  const MealAiSheet({super.key, required this.mealId, required this.name});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.lang;
    final request = (
      mealId: mealId,
      language: Localizations.localeOf(context).languageCode,
    );
    final state = ref.watch(mealAiControllerProvider(request));
    final saved = ref.watch(acceptedMealAiProvider(mealId));
    // Keep the prepared context alive for this panel. Opening never calls the LLM.
    final input = ref.watch(mealAiInputProvider(mealId));
    final displayed = state.draft ?? saved.asData?.value?.draft;
    final document = displayed?.document ?? input.asData?.value;
    final prompt =
        displayed?.prompt ??
        (document == null
            ? null
            : buildMealAiPrompt(document, request.language));
    final currentDocument = input.asData?.value;
    final currentPrompt = currentDocument == null
        ? null
        : buildMealAiPrompt(currentDocument, request.language);
    final error = state.error;
    final raw = error is MealAiInvalidResponse
        ? error.response
        : displayed?.rawResponse;
    void inspect(String text, bool response) => showDialog<void>(
      context: context,
      builder: (_) => AiTextDialog(text: text, isResponse: response),
    );
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.auto_awesome),
          title: Text(lang.mealAiTitle),
          subtitle: Text(name),
          trailing: IconButton(
            tooltip: lang.dayAiClose,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextButton.icon(
                  onPressed: prompt == null
                      ? null
                      : () => inspect(prompt, false),
                  icon: const Icon(Icons.description_outlined),
                  label: Text(lang.dayAiShowInput),
                ),
                if (state.draft == null &&
                    displayed != null &&
                    currentPrompt != null &&
                    currentPrompt != prompt)
                  TextButton.icon(
                    onPressed: () => inspect(currentPrompt, false),
                    icon: const Icon(Icons.description_outlined),
                    label: Text(lang.mealAiCurrentInput),
                  ),
                if (raw != null && !state.generating)
                  TextButton.icon(
                    onPressed: () => inspect(raw, true),
                    icon: const Icon(Icons.data_object),
                    label: Text(lang.dayAiShowResponse),
                  ),
                if (input.isLoading || saved.isLoading || state.busy)
                  const LinearProgressIndicator(),
                if (input.hasError)
                  TextButton(
                    onPressed: () =>
                        ref.read(mealAiInputProvider(mealId).notifier).retry(),
                    child: Text(lang.dayAiFailed),
                  ),
                if (saved.hasError)
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(acceptedMealAiProvider(mealId)),
                    child: Text(lang.dayAiLoadFailed),
                  ),
                if (state.saveError != null) Text(lang.dayAiSaveFailed),
                if (error != null)
                  Text(
                    error is MealAiInvalidResponse
                        ? (error.tokenLimitReached
                              ? lang.dayAiOutputLimit
                              : lang.dayAiInvalidResponse)
                        : aiRequestErrorMessage(lang, error),
                  ),
                if (displayed != null) ...[
                  Text(
                    state.draft == null ? lang.dayAiSaved : lang.dayAiPreview,
                  ),
                  Text(
                    DateFormat.yMMMd(
                      lang.localeName,
                    ).add_Hm().format(displayed.generatedAt.toLocal()),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 12),
                  MealAiResultCards(result: displayed.result),
                ] else if (!state.busy && !input.hasError && error == null)
                  Text(lang.mealAiIntro),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: MealAiActions(
              request: request,
              hasSaved: saved.asData?.value != null,
              canGenerate:
                  input.hasValue &&
                  !input.isLoading &&
                  !input.hasError &&
                  !saved.isLoading &&
                  !saved.hasError,
              canSave: !saved.isLoading && !saved.hasError,
            ),
          ),
        ),
      ],
    );
  }
}
