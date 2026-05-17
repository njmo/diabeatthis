import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/camera_search_icon.dart';
import '../../../../common/widgets/forms.dart';
import '../../../../core/domain/model/ingredient.dart' as domain;
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
        normalizedQuery.isEmpty && photoSearchResult != null;
    final ingredients = isPhotoSearchActive
        ? ref.watch(
            ingredientsByPhotoSearchCandidatesProvider(
              photoSearchCandidatesKey,
            ),
          )
        : ref.watch(ingredientsByQueryProvider(query.value));
    final hasNoPhotoSearchMatches =
        isPhotoSearchActive &&
        ingredients.hasValue &&
        (ingredients.asData?.value.isEmpty ?? false);
    final selectedIngredient = ref.watch(ingredientDraftProvider);
    final draft = ref.watch(ingredientDraftProvider.notifier);
    final formKey = ref.watch(mealIngredientFormKeyProvider);
    final addIngredientController = ref.read(
      addMealIngredientStageProvider.notifier,
    );

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IngredientSearchActions(
            isPhotoSearchLoading: photoSearchState.isLoading,
            onAddManual: addIngredientController.startManualIngredient,
            onScanLabel: addIngredientController.startIngredientPhotoScan,
            onSearchPhoto: addIngredientController.startIngredientPhotoSearch,
          ),
          const SizedBox(height: 8),
          Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
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
                    if (valuePicked.value < 0 &&
                        !selectedIngredient.hasSearchSelection) {
                      return 'Wybierz składnik albo dodaj nowy.';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Szukaj składnika',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          if (photoSearchState.isLoading) ...[
            const IngredientPhotoSearchProgressMessage(),
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
          ],
          if (photoSearchState.hasError) ...[
            IngredientPhotoSearchErrorMessage(
              message: _photoSearchErrorMessage(photoSearchState.error!),
            ),
            const SizedBox(height: 8),
          ],
          if (normalizedQuery.isEmpty && photoSearchResult != null) ...[
            IngredientPhotoSearchSummary(
              result: photoSearchResult,
              hasNoMatches: hasNoPhotoSearchMatches,
              onAddNewIngredient:
                  addIngredientController.continuePhotoSearchAsFullScan,
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            height: 240,
            child: ListView.separated(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemBuilder: (context, index) {
                final ingredient = ingredients.asData?.value[index];
                if (ingredient == null) {
                  return SizedBox.shrink();
                }
                final selected =
                    valuePicked.value == index ||
                    selectedIngredient.matchesSearchResult(ingredient);
                return IngredientSearchTile(
                  name: ingredient.name,
                  kcalPer100g: ingredient.kcalPer100g,
                  isReference: ingredient.isReference,
                  selected: selected,
                  onTap: () {
                    draft.overrideDraft(ingredient);
                    valuePicked.value = index;
                  },
                );
              },
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemCount: ingredients.asData?.value.length ?? 0,
            ),
          ),
        ],
      ),
    );
  }
}

class IngredientSearchTile extends StatelessWidget {
  final String name;
  final double? kcalPer100g;
  final bool isReference;
  final bool selected;
  final VoidCallback onTap;

  const IngredientSearchTile({
    required this.name,
    required this.kcalPer100g,
    required this.isReference,
    required this.selected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final kcalLabel = kcalPer100g == null ? '-' : kcalPer100g!.round();

    return Material(
      color: selected ? colorScheme.secondaryContainer : colorScheme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: selected ? colorScheme.secondary : colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 12, right: 8),
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: selected
              ? colorScheme.secondary
              : colorScheme.surfaceContainerHighest,
          foregroundColor: selected
              ? colorScheme.onSecondary
              : colorScheme.onSurfaceVariant,
          child: Icon(
            isReference ? Icons.dinner_dining : Icons.restaurant,
            size: 20,
          ),
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        subtitle: Text('$kcalLabel kcal / 100 g'),
        trailing: selected ? const Icon(Icons.check_circle) : null,
      ),
    );
  }
}

class IngredientSearchActions extends StatelessWidget {
  final bool isPhotoSearchLoading;
  final VoidCallback onAddManual;
  final VoidCallback onScanLabel;
  final VoidCallback onSearchPhoto;

  const IngredientSearchActions({
    required this.isPhotoSearchLoading,
    required this.onAddManual,
    required this.onScanLabel,
    required this.onSearchPhoto,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _IngredientSearchActionButton(
            icon: const Icon(Icons.add_box_outlined),
            label: 'Ręcznie',
            tooltip: 'Dodaj ręcznie',
            onPressed: onAddManual,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _IngredientSearchActionButton(
            icon: const Icon(Icons.add_a_photo_outlined),
            label: 'Etykieta',
            tooltip: 'Odczytaj etykietę',
            onPressed: onScanLabel,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _IngredientSearchActionButton(
            icon: const CameraSearchIcon(size: 18),
            label: isPhotoSearchLoading ? 'Szukam' : 'Ze zdjęcia',
            tooltip: 'Znajdź ze zdjęcia',
            onPressed: isPhotoSearchLoading ? null : onSearchPhoto,
          ),
        ),
      ],
    );
  }
}

class _IngredientSearchActionButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final String tooltip;
  final VoidCallback? onPressed;

  const _IngredientSearchActionButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme.merge(data: const IconThemeData(size: 18), child: icon),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                'Szukam ze zdjęcia.',
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
  final bool hasNoMatches;
  final VoidCallback onAddNewIngredient;

  const IngredientPhotoSearchSummary({
    required this.result,
    required this.hasNoMatches,
    required this.onAddNewIngredient,
    super.key,
  });

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

    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.manage_search_outlined,
                    color: colors.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wynik ze zdjęcia',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        recognizedText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasNoMatches) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: colors.onSurfaceVariant,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Brak pasującego składnika w bazie.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: onAddNewIngredient,
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('Dodaj nowy składnik'),
              ),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

extension IngredientSearchSelectionX on domain.Ingredient {
  bool get hasSearchSelection => map(
    draft: (draft) => draft.name.trim().isNotEmpty,
    existing: (_) => true,
  );

  bool matchesSearchResult(domain.Ingredient ingredient) {
    return map(
      draft: (draft) => ingredient.map(
        draft: (other) =>
            draft.name == other.name && draft.brand == other.brand,
        existing: (other) =>
            draft.name == other.name && draft.brand == other.brand,
      ),
      existing: (existing) => ingredient.map(
        draft: (_) => false,
        existing: (other) => existing.id == other.id,
      ),
    );
  }
}
