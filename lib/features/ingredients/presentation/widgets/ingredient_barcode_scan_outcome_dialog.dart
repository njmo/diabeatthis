import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../common/l10n/language.dart';
import '../../data/clients/open_food_facts_product_client.dart';
import '../models/ingredient_barcode_scan_outcome.dart';

Future<bool?> showIngredientBarcodeScanOutcomeDialog({
  required BuildContext context,
  required IngredientBarcodeScanOutcome outcome,
  required String? errorMessage,
}) {
  return showDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (context) {
      return IngredientBarcodeScanOutcomeDialog(
        outcome: outcome,
        errorMessage: errorMessage,
      );
    },
  );
}

class IngredientBarcodeScanOutcomeDialog extends StatelessWidget {
  final IngredientBarcodeScanOutcome outcome;
  final String? errorMessage;

  const IngredientBarcodeScanOutcomeDialog({
    required this.outcome,
    required this.errorMessage,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final viewData = IngredientBarcodeScanOutcomeViewData.fromOutcome(
      lang,
      outcome,
      errorMessage,
    );

    return AlertDialog(
      title: Text(viewData.title),
      content: Text(viewData.message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(lang.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(viewData.actionLabel),
        ),
      ],
    );
  }
}

class IngredientBarcodeScanOutcomeViewData {
  final String title;
  final String message;
  final String actionLabel;

  const IngredientBarcodeScanOutcomeViewData({
    required this.title,
    required this.message,
    required this.actionLabel,
  });

  factory IngredientBarcodeScanOutcomeViewData.fromOutcome(
    AppLocalizations lang,
    IngredientBarcodeScanOutcome outcome,
    String? errorMessage,
  ) {
    return switch (outcome.type) {
      IngredientBarcodeScanOutcomeType.existingIngredient =>
        IngredientBarcodeScanOutcomeViewData(
          title: lang.ingredientBarcodeExistingTitle,
          message: lang.ingredientBarcodeExistingMessage(
            outcome.existingIngredient!.name,
          ),
          actionLabel: lang.addIngredientNext,
        ),
      IngredientBarcodeScanOutcomeType.newDraft =>
        IngredientBarcodeScanOutcomeViewData(
          title: lang.ingredientBarcodeNewDraftTitle,
          message: lang.ingredientBarcodeNewDraftMessage,
          actionLabel: lang.ingredientBarcodeReviewDraft,
        ),
      IngredientBarcodeScanOutcomeType.needsReview =>
        IngredientBarcodeScanOutcomeViewData(
          title: lang.ingredientBarcodeNeedsReviewTitle,
          message: lang.ingredientBarcodeNeedsReviewMessage,
          actionLabel: lang.ingredientBarcodeFillIn,
        ),
      IngredientBarcodeScanOutcomeType.failed =>
        IngredientBarcodeScanOutcomeViewData(
          title: lang.ingredientBarcodeFailedTitle,
          message: errorMessage ?? lang.ingredientBarcodeNoSupplementData,
          actionLabel: lang.ingredientBarcodeBackToSearch,
        ),
    };
  }
}

class IngredientBarcodeScanInfoMessage extends StatelessWidget {
  final String message;

  const IngredientBarcodeScanInfoMessage({required this.message, super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: colors.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IngredientBarcodeScanErrorMessage extends StatelessWidget {
  final String message;

  const IngredientBarcodeScanErrorMessage({required this.message, super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colors.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String ingredientBarcodeScanErrorMessage(Object error) {
  if (error is OpenFoodFactsProductNotFoundException) {
    return lang.ingredientBarcodeProductNotFound;
  }
  if (error is OpenFoodFactsRequestException) {
    return lang.ingredientBarcodeProductRequestFailed;
  }
  if (error is TimeoutException) {
    return lang.ingredientBarcodeProductTimeout;
  }
  if (error is http.ClientException) {
    final details = error.message.trim();
    if (details.isEmpty) {
      return lang.ingredientBarcodeProductNoConnection;
    }
    return lang.ingredientBarcodeProductNoConnectionWithDetails(details);
  }
  if (error is FormatException) {
    return lang.ingredientBarcodeProductParseFailed;
  }
  return lang.ingredientBarcodeProductFetchFailed;
}

String ingredientBarcodeScanNoUsableDataMessageForError(Object? error) {
  if (error == null) {
    return lang.ingredientBarcodeNoUsableData;
  }
  return lang.ingredientBarcodeErrorWithFallback(
    ingredientBarcodeScanErrorMessage(error),
  );
}
