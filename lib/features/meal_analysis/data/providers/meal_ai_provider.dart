import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/drift/providers/database_provider.dart';
import '../../../../core/llm/analysis_llm_provider.dart';
import '../../../meals/common/models/meal_wizard_assignment.dart';
import '../../../meals/data/domain/use_cases/analyze_meal_use_case.dart';
import '../../../meals/data/domain/use_cases/load_meal_details_use_case.dart';
import '../../../meals/data/mappers/meal_ai_facts_mapper.dart';
import '../../../meals/data/providers/meal_wizard_link_repository_provider.dart';
import '../../domain/models/meal_ai_context.dart';
import '../../domain/models/meal_outcome_context.dart';
import '../../domain/services/meal_ai_client.dart';
import '../../domain/use_cases/accept_meal_ai_use_case.dart';
import '../../domain/use_cases/analyze_meal_ai_use_case.dart';
import '../../domain/use_cases/build_meal_ai_context_use_case.dart';
import '../clients/llm_meal_ai_client.dart';
import '../prompts/meal_ai_prompt.dart';
import '../repositories/meal_ai_repository.dart';
import 'build_before_meal_context_use_case_provider.dart';
import 'find_similar_meals_provider.dart';

final mealAiClientProvider = Provider<MealAiClient>(
  (ref) => LlmMealAiClient(
    transport: ref.watch(analysisLlmTransportProvider),
    modelId: analysisFirebaseModel,
  ),
);
final analyzeMealAiUseCaseProvider = Provider(
  (ref) => AnalyzeMealAiUseCase(
    client: ref.watch(mealAiClientProvider),
    now: clock.now,
    promptVersion: mealAiPromptVersion,
  ),
);
final mealAiRepositoryProvider = Provider(
  (ref) => MealAiRepository(ref.watch(databaseProvider)),
);
final acceptedMealAiProvider = FutureProvider.autoDispose.family(
  (ref, int mealId) => ref.watch(mealAiRepositoryProvider).get(mealId),
);
final acceptMealAiUseCaseProvider = Provider(
  (ref) => AcceptMealAiUseCase(
    save: ref.watch(mealAiRepositoryProvider).save,
    now: clock.now,
  ),
);

final buildMealAiContextUseCaseProvider = Provider.autoDispose((ref) {
  final load = ref.watch(loadMealDetailsUseCaseProvider);
  final analyze = ref.watch(analyzeMealUseCaseProvider);
  final before = ref.watch(buildBeforeMealContextUseCaseProvider(false));
  final similar = ref.watch(findSimilarMealsUseCaseProvider);
  final links = ref.watch(mealWizardLinkRepositoryProvider);
  return BuildMealAiContextUseCase(
    now: clock.now,
    loadObservation: (mealId, cutoff) async {
      // Both historical UI and AI use the existing analysis use case and history providers.
      final details = await load(mealId);
      List<MealWizardAssignment>? assignments;
      try {
        assignments = await links.assignmentsForMeal(mealId);
      } catch (_) {
        /* Missing links must remain unknown, never inferred from time proximity. */
      }
      final facts = const MealAiFactsMapper().map(
        details,
        cutoff: cutoff,
        wizardAssignments: assignments,
      );
      if (facts.eatenAt.isAfter(cutoff ?? clock.now())) {
        throw StateError('Future meal');
      }
      final precedingFuture = before(
        asOf: facts.eatenAt,
        mealId: mealId,
        macros: facts.macros,
      );
      MealOutcomeContext? outcome;
      try {
        outcome = (await analyze(details, asOf: cutoff))?.outcomeContext;
      } catch (_) {
        /* Missing outcome is explicit in DML; pre-meal evidence remains usable. */
      }
      final preceding = await precedingFuture;
      return MealAiObservation(
        meal: facts,
        before: preceding,
        outcome: outcome,
      );
    },
    loadSimilar: (current) async {
      final facts = current.meal;
      if (facts.macros == null) return null;
      return similar(
        mealId: facts.mealId,
        asOf: facts.eatenAt,
        target: facts.macros!,
        composition: facts.composition,
      );
    },
  );
});
