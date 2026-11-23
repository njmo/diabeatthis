import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/language.dart';
import '../../meal/recorded_meal_conversion_controller.dart';
import '../../meal/recorded_meal_conversion_request.dart';

/// Formats a stored weight so that confirming it unchanged saves the exact
/// same value: no rounding and no grouping separators.
String formatEditableGrams(double grams, String locale) {
  var text = grams.toString();
  if (text.endsWith('.0')) text = text.substring(0, text.length - 2);
  final separator = NumberFormat.decimalPattern(locale).symbols.DECIMAL_SEP;
  return separator == '.' ? text : text.replaceAll('.', separator);
}

double? parseEditableGrams(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

/// Confirms every missing historical portion weight of one meal on one screen.
///
/// Pops `true` only after all weights were saved together.
class RecordedMealConversionReviewPage extends HookConsumerWidget {
  const RecordedMealConversionReviewPage({
    super.key,
    required this.mealId,
    required this.requests,
  });

  final int mealId;
  final List<RecordedMealConversionRequest> requests;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.lang;
    final theme = Theme.of(context);
    final amountFormat = NumberFormat('0.##', lang.localeName);
    final controllers = useMemoized(
      () => [
        for (final request in requests)
          TextEditingController(
            text: request.currentGrams == null
                ? ''
                : formatEditableGrams(request.currentGrams!, lang.localeName),
          ),
      ],
      [requests],
    );
    useEffect(
      () => () {
        for (final controller in controllers) {
          controller.dispose();
        }
      },
      [controllers],
    );
    final form = useMemoized(GlobalKey<FormState>.new);
    final saving = useState(false);
    final failed = useState(false);

    Future<void> save() async {
      if (saving.value || !form.currentState!.validate()) return;
      // Every field is mounted (no lazy list), but never trust validation
      // alone before writing historical weights.
      final values = [
        for (final controller in controllers)
          parseEditableGrams(controller.text),
      ];
      if (values.any((v) => v == null || !v.isFinite || v <= 0)) return;
      saving.value = true;
      failed.value = false;
      final repaired = await ref
          .read(recordedMealConversionControllerProvider(mealId).notifier)
          .confirm({
            for (var i = 0; i < requests.length; i++) requests[i]: values[i]!,
          });
      if (!context.mounted) return;
      if (repaired) {
        Navigator.of(context).pop(true);
        return;
      }
      saving.value = false;
      failed.value = true;
    }

    return PopScope(
      canPop: !saving.value,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 52,
          titleTextStyle: theme.textTheme.titleMedium,
          title: Text(lang.mealConversionReviewTitle),
          leading: IconButton(
            tooltip: lang.commonCloseTooltip,
            icon: const Icon(Icons.close),
            onPressed: saving.value ? null : () => Navigator.of(context).pop(),
          ),
        ),
        body: Form(
          key: form,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        lang.mealConversionReviewExplanation,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lang.mealConversionScopeNote,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (var i = 0; i < requests.length; i++)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  requests[i].ingredientName,
                                  style: theme.textTheme.titleSmall,
                                ),
                                Text(
                                  '${amountFormat.format(requests[i].amount)} × '
                                  '${requests[i].portionName}',
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: controllers[i],
                                  enabled: !saving.value,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  textInputAction: i == requests.length - 1
                                      ? TextInputAction.done
                                      : TextInputAction.next,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    labelText:
                                        lang.mealConversionGramsPerPortion,
                                    suffixText: 'g',
                                    helperText: requests[i].currentGrams == null
                                        ? lang.mealConversionNoSuggestion
                                        : lang.mealConversionSuggestionHint,
                                    helperMaxLines: 2,
                                  ),
                                  validator: (text) {
                                    final value = parseEditableGrams(
                                      text ?? '',
                                    );
                                    return value == null ||
                                            !value.isFinite ||
                                            value <= 0
                                        ? lang.mealConversionInvalidWeight
                                        : null;
                                  },
                                  onFieldSubmitted: i == requests.length - 1
                                      ? (_) => save()
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (failed.value) ...[
                        Text(
                          lang.mealConversionSaveFailed,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                        const SizedBox(height: 8),
                      ],
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                        onPressed: saving.value ? null : save,
                        child: saving.value
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(lang.mealConversionConfirm),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
