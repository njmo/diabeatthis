import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/forms.dart';
import '../../../../core/llm/local_llm_client.dart';
import '../../../../core/media/providers/camera_permission_service_provider.dart';
import '../../../meal_advisor/data/models/ingredient_photo_search_result.dart';
import '../../../meal_advisor/presentation/controllers/ingredient_photo_search_controller.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../data/providers/ingredient_provider.dart';
import 'ingredient_photo_scan.dart';

const int _ingredientSearchMaxLength = 120;

class IngredientSearch extends HookConsumerWidget {
  const IngredientSearch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = useState('');
    final valuePicked = useState(-1);
    final normalizedQuery = query.value.trim();
    final photoSearchState = ref.watch(ingredientPhotoSearchControllerProvider);
    final photoSearch = photoSearchState.value;
    final photoSearchResult = photoSearch?.result;
    final photoSearchCandidatesKey = photoSearchResult?.candidatesKey ?? '';
    final isPhotoSearchActive =
        normalizedQuery.isEmpty && photoSearchCandidatesKey.isNotEmpty;
    final ingredients = isPhotoSearchActive
        ? ref.watch(
            ingredientsByPhotoSearchCandidatesProvider(
              photoSearchCandidatesKey,
            ),
          )
        : ref.watch(ingredientsByQueryProvider(query.value));
    final draft = ref.watch(ingredientDraftProvider.notifier);
    final formKey = ref.watch(mealIngredientFormKeyProvider);
    final addIngredientStage = ref.read(
      addMealIngredientStageProvider.notifier,
    );

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.always,
            child: StringFormField(
              label: 'Nazwa',
              value: '',
              onChanged: (value) {
                query.value = value;
              },
              builder: (context, controller) {
                return TextFormField(
                  autofocus: true,
                  controller: controller,
                  maxLength: _ingredientSearchMaxLength,
                  validator: (value) {
                    if (valuePicked.value < 0) {
                      return '';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    icon: Icon(Icons.search),
                    labelText: 'Nazwa',
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 16),
          if (photoSearchState.isLoading) ...[
            const IngredientPhotoSearchProgressMessage(),
            const SizedBox(height: 12),
          ],
          if (photoSearch?.captureError != null) ...[
            IngredientPhotoCaptureMessage(
              result: photoSearch!.captureError!,
              onOpenSettings: photoSearch.captureError!.canOpenSettings
                  ? () {
                      ref.read(cameraPermissionServiceProvider).openSettings();
                    }
                  : null,
            ),
            const SizedBox(height: 12),
          ],
          if (photoSearchState.hasError) ...[
            IngredientPhotoSearchErrorMessage(
              message: _photoSearchErrorMessage(photoSearchState.error!),
            ),
            const SizedBox(height: 12),
          ],
          if (normalizedQuery.isEmpty && photoSearchResult != null) ...[
            IngredientPhotoSearchSummary(result: photoSearchResult),
            const SizedBox(height: 12),
          ],
          if (isPhotoSearchActive &&
              ingredients.hasValue &&
              (ingredients.asData?.value.isEmpty ?? false)) ...[
            IngredientPhotoSearchEmptyMessage(
              onContinueWithScan:
                  addIngredientStage.continuePhotoSearchAsFullScan,
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemBuilder: (context, index) {
                final ingredient = ingredients.asData?.value[index];
                if (ingredient == null) {
                  return SizedBox.shrink();
                }
                return Card(
                  child: ListTile(
                    title: Text(
                      ingredient.name,
                      style: TextStyle(
                        fontWeight: (valuePicked.value == index)
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text('Kalorie: ${ingredient.kcalPer100g} kcal'),
                    trailing: ingredient.isReference
                        ? const Icon(Icons.dinner_dining)
                        : null,
                    onTap: () {
                      draft.overrideDraft(ingredient);
                      valuePicked.value = index;
                    },
                  ),
                );
              },
              itemCount: ingredients.asData?.value.length ?? 0,
              shrinkWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}

class IngredientPhotoSearchProgressMessage extends StatelessWidget {
  const IngredientPhotoSearchProgressMessage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Szukam produktu na podstawie zdjęcia.',
                style: TextStyle(color: colors.onPrimaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IngredientPhotoSearchSummary extends StatelessWidget {
  final IngredientPhotoSearchResult result;

  const IngredientPhotoSearchSummary({required this.result, super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final names = result.names.join(', ');
    final brand = result.brand;
    final recognizedText = switch ((names.isNotEmpty, brand)) {
      (true, final String brand) => 'Rozpoznano: $names, marka: $brand',
      (true, null) => 'Rozpoznano: $names',
      (false, final String brand) => 'Rozpoznano markę: $brand',
      (false, null) => 'Rozpoznano zdjęcie produktu.',
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.manage_search_outlined,
              color: colors.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                recognizedText,
                style: TextStyle(color: colors.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IngredientPhotoSearchEmptyMessage extends StatelessWidget {
  final VoidCallback onContinueWithScan;

  const IngredientPhotoSearchEmptyMessage({
    required this.onContinueWithScan,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: colors.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Nie znalazłem podobnego składnika w bazie. Dodaj zdjęcie tabeli makro, żeby utworzyć nowy składnik.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onContinueWithScan,
              child: const Text('Dodaj makro'),
            ),
          ],
        ),
      ),
    );
  }
}

class IngredientPhotoSearchErrorMessage extends StatelessWidget {
  final String message;

  const IngredientPhotoSearchErrorMessage({required this.message, super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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

String _photoSearchErrorMessage(Object error) {
  if (error is LlmRequestException) {
    return switch (error.failure) {
      LlmRequestFailure.network =>
        'Brak połączenia z AI. Sprawdź internet i spróbuj ponownie.',
      LlmRequestFailure.unauthorized =>
        'Nie udało się potwierdzić aplikacji w Firebase.',
      LlmRequestFailure.quotaExceeded =>
        'Limit odczytów AI został wyczerpany. Spróbuj później.',
      LlmRequestFailure.timeout => 'Odczyt trwał zbyt długo. Spróbuj ponownie.',
      LlmRequestFailure.unavailable =>
        'AI jest chwilowo niedostępne. Spróbuj ponownie.',
    };
  }
  if (error is FormatException) {
    return 'Nie udało się odczytać odpowiedzi modelu. Spróbuj ponownie.';
  }
  return 'Nie udało się wyszukać produktu ze zdjęcia. Spróbuj ponownie.';
}
