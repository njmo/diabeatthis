import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../features/ingredients/presentation/screens/ingredient_photo_camera_screen.dart';
import '../../../features/meal_photo/data/catalog_meal_photo_candidate_repository.dart';
import '../../../features/meal_photo/data/local_llm_meal_photo_recognition_client.dart';
import '../../../features/meal_photo/domain/models/meal_photo_timing_selection.dart';
import '../../../features/meal_photo/domain/use_cases/propose_meal_from_photo_use_case.dart';
import '../../../features/meal_photo/presentation/controllers/meal_photo_controller.dart';
import '../../../features/meal_photo/presentation/screens/meal_photo_review_screen.dart';
import '../../../features/meal_photo/presentation/widgets/meal_photo_capture_step.dart';
import '../../../features/meal_photo/presentation/widgets/meal_photo_timing_summary.dart';
import '../../ai/ai_client_providers.dart';
import '../../ingredient_catalog/ingredient_catalog_providers.dart';
import '../../ingredient_catalog/unified_ingredient_search_use_case.dart';
import '../../l10n/language.dart';
import '../../meal/meal_category.dart';
import '../../planning/planning_repository_provider.dart';
import '../../routing/form_route_guard.dart';
import '../photo/family_photo_ingredient_reader.dart';
import '../photo/family_photo_plan_saver.dart';
import 'show_family_ingredient_picker.dart';

/// Shares recognition/review with the child, replacing persistence with a proposal.
class FamilyMealPhotoPage extends HookConsumerWidget {
  const FamilyMealPhotoPage({super.key, required this.ingredients});
  final FamilyPhotoIngredientReader ingredients;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = useState<MealCategory?>(null);
    final planned = useState(DateTime.now().add(const Duration(hours: 1)));
    final catalog = ref.watch(catalogRepositoryProvider);
    final ai = ref.watch(aiPhotoClientProvider);
    final candidates = useMemoized(
      () => CatalogMealPhotoCandidateRepository(
        searchUseCase: UnifiedIngredientSearchUseCase(
          local: ingredients,
          catalog: catalog,
        ),
        catalog: catalog,
        local: ingredients,
      ),
      [catalog, ingredients],
    );
    final controller = useMemoized(
      () => MealPhotoController(
        allowIngredientCreation: false,
        propose: ProposeMealFromPhotoUseCase(
          client: LocalLlmMealPhotoRecognitionClient(ai),
          candidates: candidates,
        ),
        saver: FamilyPhotoPlanSaver(
          submit: (values) =>
              ref.read(planningRepositoryProvider).proposeMeal(values),
          category: () => category.value,
          plannedAt: () => planned.value,
        ),
      ),
      [candidates, ai],
    );
    useEffect(() => controller.dispose, [controller]);
    useListenable(controller);
    final language = Localizations.localeOf(context).languageCode;
    final allAssigned =
        controller.state.items.isNotEmpty &&
        controller.state.items.every((item) => item.product != null);
    return MealPhotoReviewScreen(
      controller: controller,
      allowIngredientCreation: false,
      confirmLabel: context.lang.familyPlanMeal,
      canConfirm:
          category.value != null &&
          planned.value.isAfter(DateTime.now()) &&
          allAssigned,
      reviewOptions: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.lang.familyPhotoPlanningHint),
          MealPhotoTimingSummary(
            selection: MealPhotoTimingSelection(
              mode: MealPhotoTimingMode.planned,
              plannedAt: planned.value,
            ),
            now: DateTime.now(),
            allowUseNow: false,
            planningHorizonDays: 365,
            enabled: !controller.state.saving,
            onDateSelected: (date) => planned.value = date,
            onUseNow: () {},
          ),
        ],
      ),
      capture: MealPhotoCaptureStep(
        categorySelected: category.value != null,
        categorySummary: category.value?.label(context.lang),
        needsClarification: controller.state.clarification != null,
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
        capturePhoto: (context, menu) {
          final guard = formRouteGuardOf(context);
          return Navigator.of(context).push<String>(
            MaterialPageRoute(
              builder: (_) => guard(
                IngredientPhotoCameraScreen(
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
          );
        },
        onGenerate: (input) =>
            controller.generate(input, languageCode: language),
      ),
      pickProduct: (context) async {
        final selected = await showFamilyIngredientSearchPicker(
          context,
          local: ingredients,
          catalog: catalog,
          queryDebounce: const Duration(milliseconds: 250),
        );
        return selected == null
            ? null
            : candidates.resolve(selected, languageCode: language);
      },
      onSaved: (_) => Navigator.of(context).pop(),
    );
  }
}
