import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/drift/providers/database_provider.dart';
import '../../../../core/llm/analysis_llm_provider.dart';
import '../../../meals/data/domain/use_cases/analyze_meal_use_case.dart';
import '../../../meals/data/domain/use_cases/load_meal_details_use_case.dart';
import '../../../meals/data/providers/meal_wizard_link_repository_provider.dart';
import '../../domain/services/meal_ai_client.dart';
import '../../domain/use_cases/accept_meal_ai_use_case.dart';
import '../../domain/use_cases/analyze_meal_ai_use_case.dart';
import '../../domain/use_cases/build_meal_ai_context_use_case.dart';
import '../clients/llm_meal_ai_client.dart';
import '../domain/use_cases/build_recorded_meal_context_use_case.dart';
import '../prompts/meal_ai_prompt.dart';
import '../repositories/meal_ai_repository.dart';
import 'build_before_meal_context_use_case_provider.dart';

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

final buildRecordedMealContextUseCaseProvider = Provider.autoDispose((ref) {
  final load = ref.watch(loadMealDetailsUseCaseProvider);
  final analyze = ref.watch(analyzeMealUseCaseProvider);
  final before = ref.watch(buildBeforeMealContextUseCaseProvider(false));
  final links = ref.watch(mealWizardLinkRepositoryProvider);
  return BuildRecordedMealContextUseCase(
    now: clock.now,
    loadDetails: load.call,
    loadAssignments: links.assignmentsForMeal,
    loadBefore: (facts) =>
        before(asOf: facts.eatenAt, mealId: facts.mealId, macros: facts.macros),
    loadOutcome: (details, cutoff) async =>
        (await analyze(details, asOf: cutoff))?.outcomeContext,
  );
});

final buildMealAiContextUseCaseProvider = Provider.autoDispose((ref) {
  final recorded = ref.watch(buildRecordedMealContextUseCaseProvider);
  return BuildMealAiContextUseCase(
    now: clock.now,
    loadObservation: recorded.call,
    // Retrospective analysis concerns this meal only. Similar cases belong to
    // the before-meal advisor, which uses the same recorded context builder.
    loadSimilar: (_) async => null,
  );
});
