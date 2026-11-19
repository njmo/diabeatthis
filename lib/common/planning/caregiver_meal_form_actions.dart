import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ingredients/data/drafts/ingredient_draft.dart';
import '../../features/ingredients/data/drafts/ingredient_portion_draft.dart';
import '../../features/ingredients/data/mappers/ingredient_draft_mapper.dart';
import '../../features/ingredients/data/models/ingredient_portion_data.dart';
import '../../features/meals/data/drafts/meal_draft.dart';
import '../../features/meals/data/models/retrospective_meal_timing.dart';
import '../../features/meals/data/providers/meal_draft_provider.dart';
import '../../features/portions/data/drafts/portion_draft.dart';
import '../family_sync/presentation/models/family_ingredient_view.dart';
import '../family_sync/presentation/show_family_ingredient_picker.dart';
import '../ingredient_catalog/ingredient_catalog_repository.dart';
import '../ingredient_catalog/ingredient_identity.dart';
import '../ingredient_catalog/ingredient_search_item.dart';
import '../l10n/language.dart';
import '../routing/form_route_guard.dart';
import 'meal_form_actions.dart';
import 'meal_ingredient_amount_sheet.dart';
import 'planning_repository_provider.dart';

class CaregiverMealFormActions extends MealFormActions {
  CaregiverMealFormActions({required this.rows, required this.catalog});
  final List<Map<String, dynamic>> rows;
  final IngredientCatalogRepository catalog;
  bool pending = false;
  bool disposed = false;
  @override
  bool get saving => pending;
  @override
  bool get showNotes => true;
  @override
  int get planningHorizonDays => 365;
  @override
  bool get canCopy => true;
  @override
  bool get allowLocalLookups => false;
  @override
  bool canContinue(MealDraft draft) =>
      draft.mealIngredients.every((item) => item.catalogReviewed);
  @override
  String? hint(BuildContext context, MealDraft draft) =>
      canContinue(draft) ? null : context.lang.familyPlanReviewCatalog;
  @override
  String failureMessage(BuildContext context, Object error) =>
      context.lang.familyPlanFailed;
  @override
  Future<MealIngredientsDraft?> pickIngredient(
    BuildContext context,
    WidgetRef ref, {
    MealIngredientsDraft? initial,
    IngredientSearchItem? selection,
  }) async {
    var draft = initial;
    if (draft == null || !draft.catalogReviewed) {
      final selected =
          selection ??
          await showFamilyIngredientPicker(
            context,
            rows: rows,
            catalog: catalog,
          );
      if (selected == null || !context.mounted) return null;
      IngredientDraft ingredient;
      String? catalogId;
      String? catalogRevision;
      final id = selected.localIngredientId;
      if (id != null) {
        ingredient = familyIngredientView(
          rows.singleWhere(
            (r) =>
                r['kind'] == 'ingredients' &&
                r['deleted'] != true &&
                r['id'] == '$id',
          ),
        ).toDraft();
      } else {
        if (selected.identity.source != IngredientSource.firebase) {
          throw StateError('Unsupported catalog');
        }
        final food = await catalog.get(
          selected.identity,
          languageCode: Localizations.localeOf(context).languageCode,
        );
        ingredient = IngredientDraft.draft(
          name: food.name,
          carbsPer100g: food.carbsPer100g,
          fatPer100g: food.fatPer100g,
          fiberPer100g: food.fiberPer100g,
          proteinPer100g: food.proteinPer100g,
          nutritionConfidence: .25,
          carbsLabelMode: food.carbsLabelMode,
          isReference: false,
        );
        catalogId = food.identity.sourceId;
        catalogRevision = food.revision;
      }
      if (!context.mounted) return null;
      final factor = ingredient.isReference ? 100.0 : 1.0;
      final oldGrams = initial == null
          ? null
          : initial.amount *
                (initial.recordedGramsPerAmount ??
                    initial.ingredientPortion.amount);
      draft = MealIngredientsDraft(
        ingredient: ingredient,
        catalogId: catalogId,
        catalogRevision: catalogRevision,
        catalogReviewed: true,
        ingredientPortion: IngredientPortionDraft(
          portion: const PortionSelection.empty(),
          amount: ingredient.isReference ? 100 : 1,
        ),
        recordedGramsPerAmount: ingredient.isReference ? 100 : 1,
        amount: oldGrams == null
            ? (ingredient.isReference ? 1 : 100)
            : oldGrams / factor,
        quantityConfidence: initial?.quantityConfidence ?? 1,
        entryType: 'planned',
        consumedAmount: null,
        consumedConfidence: null,
      );
    }
    final ingredientId = draft.ingredient.getIngredientIdOrNull();
    final portions = <IngredientPortionData>[];
    if (ingredientId != null && !draft.ingredient.isReference) {
      for (final row in rows) {
        if (row['kind'] != 'ingredientPortions' || row['deleted'] == true) {
          continue;
        }
        final link = row['payload'] as Map;
        if (link['ingredient_id'] != ingredientId) {
          continue;
        }
        final weight = (link['grams_per_portion'] as num?)?.toDouble();
        if (weight == null || !weight.isFinite || weight <= 0) {
          continue;
        }
        final matches = rows.where(
          (item) =>
              item['kind'] == 'portions' &&
              item['deleted'] != true &&
              (item['payload'] as Map)['id'] == link['portion_id'],
        );
        if (matches.isEmpty) {
          continue;
        }
        final portion = matches.first['payload'] as Map;
        portions.add(
          IngredientPortionData(
            portionId: portion['id'] as int,
            name: portion['name'] as String,
            unitHint: portion['unit_hint'] as String? ?? '',
            gramsPerPortion: weight,
          ),
        );
      }
    }
    final guard = formRouteGuardOf(context);
    final result = await showModalBottomSheet<MealIngredientsDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          guard(MealIngredientAmountSheet(draft: draft!, portions: portions)),
    );
    return result;
  }

  @override
  Future<Object?> save(
    WidgetRef ref,
    AppLocalizations language, {
    RetrospectiveMealTiming? retrospective,
  }) async {
    if (pending || !canContinue(ref.read(mealDraftProvider))) {
      throw StateError('Review the plan before submitting');
    }
    pending = true;
    notifyListeners();
    try {
      return await ref
          .read(planningRepositoryProvider)
          .saveMeal(
            ref.read(mealDraftProvider),
            automaticName: false,
            language: language,
            retrospective: retrospective,
          );
    } finally {
      pending = false;
      if (!disposed) notifyListeners();
    }
  }

  @override
  void close(BuildContext context, Object? result) =>
      Navigator.of(context).pop();
  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}
