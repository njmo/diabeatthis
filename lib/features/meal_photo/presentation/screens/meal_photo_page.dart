import 'dart:async';
import 'dart:developer' as developer;

import 'package:auto_route/auto_route.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/ingredient_catalog/ingredient_search_item.dart';
import '../../../../common/ingredient_catalog/ingredient_search_normalizer.dart';
import '../../../../common/ingredient_catalog/widgets/ingredient_catalog_picker.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/location/residence_country_provider.dart';
import '../../../../common/meal/meal_category.dart';
import '../../../dashboard/data/providers/time_now_provider.dart';
import '../../../dashboard/presentation/utils/meal_status_dialog_result_handler.dart';
import '../../../dashboard/presentation/utils/show_meal_status_dialog.dart';
import '../../../dashboard/presentation/widgets/meal_status_dialog_result.dart';
import '../../../ingredients/presentation/screens/ingredient_photo_camera_screen.dart';
import '../../../meals/data/providers/meal_database_provider.dart';
import '../../data/meal_photo_draft_settings.dart';
import '../../domain/models/meal_photo_timing_selection.dart';
import '../controllers/meal_photo_saved_action_controller.dart';
import '../controllers/meal_photo_timing_controller.dart';
import '../providers/meal_photo_providers.dart';
import '../widgets/meal_photo_capture_step.dart';
import '../widgets/meal_photo_timing_summary.dart';
import 'meal_photo_review_screen.dart';

@RoutePage()
class MealPhotoPage extends HookConsumerWidget {
  const MealPhotoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = useState<MealCategory?>(null);
    final residenceCountry = ref.watch(residenceCountryProvider).asData?.value;
    final timing = useMemoized(MealPhotoTimingController.new);
    useEffect(() => timing.dispose, [timing]);
    useListenable(timing);
    ref.watch(timeNowProvider);
    final now = clock.now();
    final timingSelection = timing.selection;
    final committedEatNow = useRef<bool?>(null);
    final savedActions = useMemoized(
      () => MealPhotoSavedActionController<MealStatusDialogResult>(
        readMeal: (id) => ref.read(getMealByIdProvider(id).future),
        presentActions: (meal) => context.mounted
            ? showMealStatusDialog(
                context: context,
                meal: meal,
                startImmediately: true,
              )
            : Future.value(null),
        applyAction: (meal, result) async {
          if (context.mounted) {
            await handleMealStatusDialogResult(
              context: context,
              ref: ref,
              meal: meal,
              result: result,
              openSummaryAfterEaten: false,
            );
          }
        },
        onFinished: (outcome) {
          if (!context.mounted) return;
          if (outcome.actionFailed) {
            developer.log(
              'Meal saved; subsequent meal action failed',
              name: 'meal_photo',
              error: outcome.error,
              stackTrace: outcome.stackTrace,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.lang.mealPhotoSavedActionFailure)),
            );
          }
          Navigator.of(context).pop(outcome.mealId);
        },
      ),
    );
    useEffect(() => savedActions.dispose, [savedActions]);
    useListenable(savedActions);
    final factory = ref.watch(mealPhotoControllerFactoryProvider);
    final controller = useMemoized(
      () => factory(() {
        final selected = category.value;
        if (selected == null) {
          throw StateError(context.lang.mealCategoryRequired);
        }
        final plannedAt = timing.selection.resolveAt(clock.now());
        committedEatNow.value =
            timing.selection.mode == MealPhotoTimingMode.eatNow;
        return MealPhotoDraftSettings(category: selected, plannedAt: plannedAt);
      }),
      [factory, timing],
    );
    useEffect(() => controller.dispose, [controller]);
    useListenable(controller);
    final language = Localizations.localeOf(context).languageCode;

    return PopScope(
      canPop: !savedActions.busy,
      child: AbsorbPointer(
        absorbing: savedActions.busy,
        child: MealPhotoReviewScreen(
          controller: controller,
          canConfirm: timing.selection.isValidAt(now) && !savedActions.busy,
          confirmLabel: timingSelection.mode == MealPhotoTimingMode.eatNow
              ? context.lang.mealPhotoStartMeal
              : context.lang.commonSave,
          reviewOptions: MealPhotoTimingSummary(
            selection: timingSelection,
            now: now,
            enabled: !controller.state.saving && !savedActions.busy,
            onUseNow: () => timing.chooseMode(MealPhotoTimingMode.eatNow),
            onDateSelected: (date) {
              if (identical(timing.selection, timingSelection)) {
                timing.chooseMode(MealPhotoTimingMode.planned);
                timing.chooseDate(date);
              }
            },
          ),
          capture: MealPhotoCaptureStep(
            needsClarification: controller.state.clarification != null,
            categorySelected: category.value != null,
            categorySummary: category.value?.label(context.lang),
            categoryField: DropdownButtonFormField<MealCategory>(
              decoration: InputDecoration(
                labelText: context.lang.mealCategoryRequired,
              ),
              initialValue: category.value,
              items: MealCategory.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.label(context.lang)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => category.value = value,
            ),
            capturePhoto: (context, menu) => Navigator.of(context).push<String>(
              MaterialPageRoute(
                builder: (_) => IngredientPhotoCameraScreen(
                  title: menu
                      ? context.lang.mealPhotoCompositionMenu
                      : context.lang.mealPhotoPlate,
                  instructions: menu
                      ? context.lang.mealPhotoDescription
                      : context.lang.mealPhotoCameraScaleHint,
                  maxDimension: 1600,
                ),
              ),
            ),
            onGenerate: (input) {
              if (category.value == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.lang.mealCategoryRequired)),
                );
                return;
              }
              FocusScope.of(context).unfocus();
              controller.generate(
                input.withResidenceCountry(residenceCountry),
                languageCode: language,
              );
            },
          ),
          findReferenceMatches: (name) async {
            final results = await ref
                .read(mealPhotoCandidatesProvider)
                .search(name, languageCode: language);
            return results
                .where(
                  (product) =>
                      normalizeIngredientSearch(product.name) ==
                      normalizeIngredientSearch(name),
                )
                .toList();
          },
          pickProduct: (context) async {
            final selected = await showIngredientCatalogPicker(
              context,
              includeReferenceIngredients: false,
              searchOnly: true,
            );
            if (selected == null || !context.mounted) return null;
            return ref
                .read(mealPhotoCandidatesProvider)
                .resolve(selected, languageCode: language);
          },
          pickProductForItem: (context, item) async {
            final candidates = ref.read(mealPhotoCandidatesProvider);
            final currentProduct = item.product ?? item.suggestedProduct;
            final selected = await showIngredientCatalogPicker(
              context,
              includeReferenceIngredients: false,
              searchOnly: true,
              initialQuery: currentProduct?.name ?? item.displayName,
              selectedItem: currentProduct == null
                  ? null
                  : IngredientSearchItem(
                      identity: currentProduct.identity,
                      name: currentProduct.name,
                      localIngredientId: currentProduct.localIngredientId,
                      iconAssetPath: currentProduct.iconAssetPath,
                      sourceRevision: currentProduct.catalogRevision,
                    ),
            );
            if (selected == null || !context.mounted) return null;
            return candidates.resolve(selected, languageCode: language);
          },
          onSaved: (id) => unawaited(
            savedActions
                .process(id, eatNow: committedEatNow.value ?? false)
                .then<void>((_) {}),
          ),
        ),
      ),
    );
  }
}
