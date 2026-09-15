import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/llm/firebase_ai_llm_client.dart';
import '../../domain/services/day_analysis_client.dart';
import '../../domain/use_cases/analyze_day_summary_use_case.dart';
import '../clients/llm_day_analysis_client.dart';
import '../prompts/day_analysis_prompt.dart';

/// Independent of the model used for ingredient photo recognition.
const dayAnalysisFirebaseModel = 'gemini-2.5-flash';

/// The single composition point to replace when enabling on-device analysis.
final dayAnalysisClientProvider = Provider<DayAnalysisClient>(
  (ref) => LlmDayAnalysisClient(
    transport: const FirebaseAiLlmClient(
      modelName: dayAnalysisFirebaseModel,
      gateway: FirebaseAiGenerateContentGateway(
        maxOutputTokens: 8192,
        thinkingBudget: 2048,
      ),
    ),
    modelId: dayAnalysisFirebaseModel,
  ),
);

/// Explicit action: obtaining the use case does not start remote generation.
final analyzeDaySummaryUseCaseProvider = Provider(
  (ref) => AnalyzeDaySummaryUseCase(
    client: ref.watch(dayAnalysisClientProvider),
    now: clock.now,
    promptVersion: dayAnalysisPromptVersion,
  ),
);
