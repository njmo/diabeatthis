import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/llm/local_llm_client.dart';
import '../../../../core/logger/logger.dart';
import '../../data/providers/accepted_day_ai_provider.dart';
import '../../data/providers/day_analysis_provider.dart';
import '../../data/providers/day_summary_provider.dart';
import '../../domain/models/day_dml_document.dart';
import '../../domain/models/day_summary_snapshot.dart';
import 'day_ai_state.dart';
import 'day_analysis_input_controller.dart';

typedef DayAiRequest = ({DateTime date, String language});

final dayAiControllerProvider = NotifierProvider.autoDispose
    .family<DayAiController, DayAiState, DayAiRequest>(DayAiController.new);

class DayAiController extends Notifier<DayAiState> with Logging {
  final DayAiRequest request;
  DayAiController(this.request);

  @override
  DayAiState build() => const DayAiState();

  ProviderSubscription<AsyncValue<DayDmlDocument?>>? _inputSubscription;

  Future<void> accept() async {
    final draft = state.draft;
    if (state.isBusy || draft == null) return;
    state = DayAiState(draft: draft, isSaving: true);
    // Obtain the repository callback before awaiting, even if the panel closes.
    try {
      final save = ref.read(acceptDayAnalysisUseCaseProvider);
      await save(daySummaryKey(request.date), draft);
      if (!ref.mounted) return;
      ref.invalidate(acceptedDayAiProvider(request.date));
      state = const DayAiState();
    } catch (error) {
      if (ref.mounted) state = DayAiState(draft: draft, saveError: error);
    }
  }

  void discard() {
    if (!state.isBusy) state = const DayAiState();
  }

  Future<void> generate() async {
    if (state.isBusy) return;
    final previousDraft = state.draft;
    state = DayAiState(draft: previousDraft, isGenerating: true);
    logI('Loading accepted day for AI analysis');
    try {
      final accepted = await ref.read(
        acceptedDaySummaryProvider(request.date).future,
      );
      if (!ref.mounted) return;
      if (accepted == null) throw StateError('An accepted day is required');
      // Lazily retain one prepared input for this panel, including retries.
      // Ref closes this subscription when the controller is disposed.
      _inputSubscription ??= ref.listen(
        dayDmlProvider(request.date),
        (_, _) {},
      );
      final document = await ref.read(dayDmlProvider(request.date).future);
      if (!ref.mounted) return;
      if (document == null) throw StateError('Day input is unavailable');
      final analyze = ref.read(analyzeDaySummaryUseCaseProvider);
      final result = await analyze(document, language: request.language);
      if (ref.mounted) state = DayAiState(draft: result);
    } catch (error, stack) {
      final failure = error is LlmRequestException
          ? error.failure.name
          : 'unknown';
      logE(
        'Day AI failed: type=${error.runtimeType}, failure=$failure',
        stackTrace: stack,
      );
      if (ref.mounted) state = DayAiState(draft: previousDraft, error: error);
    }
  }
}
