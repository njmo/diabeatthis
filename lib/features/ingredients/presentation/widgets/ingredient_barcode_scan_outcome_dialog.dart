import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
    final viewData = IngredientBarcodeScanOutcomeViewData.fromOutcome(
      outcome,
      errorMessage,
    );

    return AlertDialog(
      title: Text(viewData.title),
      content: Text(viewData.message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Anuluj'),
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
    IngredientBarcodeScanOutcome outcome,
    String? errorMessage,
  ) {
    return switch (outcome.type) {
      IngredientBarcodeScanOutcomeType.existingIngredient =>
        IngredientBarcodeScanOutcomeViewData(
          title: 'Znaleziono składnik',
          message:
              'Kod pasuje do składnika "${outcome.existingIngredient!.name}". Przejdziesz do wyboru porcji i ilości.',
          actionLabel: 'Przejdź dalej',
        ),
      IngredientBarcodeScanOutcomeType.newDraft =>
        const IngredientBarcodeScanOutcomeViewData(
          title: 'Pobrano dane produktu',
          message:
              'Uzupełniłem szkic składnika danymi z Open Food Facts. Sprawdź pola przed dodaniem.',
          actionLabel: 'Sprawdź szkic',
        ),
      IngredientBarcodeScanOutcomeType.needsReview =>
        const IngredientBarcodeScanOutcomeViewData(
          title: 'Pobrano część danych',
          message:
              'Nie udało się uzupełnić wszystkich pól. Przejdziesz do formularza, żeby sprawdzić i uzupełnić składnik.',
          actionLabel: 'Uzupełnij',
        ),
      IngredientBarcodeScanOutcomeType.failed =>
        IngredientBarcodeScanOutcomeViewData(
          title: 'Nie znaleziono danych składnika',
          message:
              errorMessage ??
              'Kod został odczytany, ale nie udało się pobrać danych potrzebnych do uzupełnienia składnika.',
          actionLabel: 'Wróć do wyszukiwania',
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
    return 'Nie znalazłem produktu w Open Food Facts.';
  }
  if (error is OpenFoodFactsRequestException) {
    return 'Nie udało się pobrać produktu z Open Food Facts.';
  }
  if (error is TimeoutException) {
    return 'Open Food Facts nie odpowiedziało na czas.';
  }
  if (error is http.ClientException) {
    final details = error.message.trim();
    if (details.isEmpty) {
      return 'Brak połączenia z Open Food Facts.';
    }
    return 'Brak połączenia z Open Food Facts: $details';
  }
  if (error is FormatException) {
    return 'Nie udało się odczytać danych produktu.';
  }
  return 'Kod został odczytany, ale nie udało się pobrać danych produktu.';
}

String ingredientBarcodeScanNoUsableDataMessageForError(Object? error) {
  if (error == null) {
    return ingredientBarcodeScanNoUsableDataMessage;
  }
  return '${ingredientBarcodeScanErrorMessage(error)} Możesz wyszukać składnik ręcznie albo użyć zdjęć etykiety.';
}
