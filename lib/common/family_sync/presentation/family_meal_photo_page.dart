import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../features/ingredients/presentation/screens/ingredient_photo_camera_screen.dart';
import '../../../features/meal_photo/data/catalog_meal_photo_candidate_repository.dart';
import '../../../features/meal_photo/data/local_llm_meal_photo_recognition_client.dart';
import '../../../features/meal_photo/domain/use_cases/propose_meal_from_photo_use_case.dart';
import '../../../features/meal_photo/presentation/controllers/meal_photo_controller.dart';
import '../../../features/meal_photo/presentation/screens/meal_photo_review_screen.dart';
import '../../../features/meal_photo/presentation/widgets/meal_photo_capture_step.dart';
import '../../ai/ai_client_providers.dart';
import '../../ingredient_catalog/ingredient_catalog_providers.dart';
import '../../ingredient_catalog/unified_ingredient_search_use_case.dart';
import '../../l10n/language.dart';
import '../../meal/meal_category.dart';
import '../family_ingredient_search_repository.dart';
import '../photo/family_photo_ingredient_reader.dart';
import '../photo/family_photo_plan_saver.dart';
import 'family_plan_time_field.dart';
import 'show_family_ingredient_picker.dart';

/// Shares recognition/review with the child, replacing persistence with a proposal.
class FamilyMealPhotoPage extends HookConsumerWidget {
  const FamilyMealPhotoPage({
    super.key,
    required this.rows,
    required this.onSubmit,
  });
  final List<Map<String, dynamic>> rows;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = useState<MealCategory?>(null);
    final planned = useState(DateTime.now().add(const Duration(hours: 1)));
    final catalog = ref.watch(catalogRepositoryProvider);
    final ai = ref.watch(aiPhotoClientProvider);
    final candidates = useMemoized(
      () => CatalogMealPhotoCandidateRepository(
        searchUseCase: UnifiedIngredientSearchUseCase(
          local: FamilyIngredientSearchRepository(rows),
          catalog: catalog,
        ),
        catalog: catalog,
        local: FamilyPhotoIngredientReader(rows),
      ),
      [catalog, rows],
    );
    final controller = useMemoized(
      () => MealPhotoController(
        allowIngredientCreation: false,
        propose: ProposeMealFromPhotoUseCase(
          client: LocalLlmMealPhotoRecognitionClient(ai),
          candidates: candidates,
        ),
        saver: FamilyPhotoPlanSaver(
          submit: onSubmit,
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
          FamilyPlanTimeField(
            value: planned.value,
            onChanged: (date) => planned.value = date,
            label: context.lang.familyPlanTime,
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
        onGenerate: (input) =>
            controller.generate(input, languageCode: language),
      ),
      pickProduct: (context) async {
        final selected = await showFamilyIngredientPicker(
          context,
          rows: rows,
          catalog: catalog,
        );
        return selected == null
            ? null
            : candidates.resolve(selected, languageCode: language);
      },
      onSaved: (_) => Navigator.of(context).pop(),
    );
  }
}
