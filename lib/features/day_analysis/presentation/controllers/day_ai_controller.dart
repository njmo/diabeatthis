import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/llm/local_llm_client.dart';
import '../../../../core/logger/logger.dart';
import '../../data/providers/day_analysis_provider.dart';
import '../../data/providers/day_summary_provider.dart';
import '../../domain/models/day_analysis_draft.dart';
import 'day_analysis_input_controller.dart';

typedef DayAiRequest = ({DateTime date, String language});

final dayAiControllerProvider = AsyncNotifierProvider.autoDispose
    .family<DayAiController, DayAnalysisDraft?, DayAiRequest>(
      DayAiController.new,
    );

class DayAiController extends AsyncNotifier<DayAnalysisDraft?> with Logging {
  final DayAiRequest request;
  DayAiController(this.request);

  @override
  FutureOr<DayAnalysisDraft?> build() => null;

  Future<void> generate() async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    logI('Loading accepted day for AI analysis');
    try {
      final accepted = await ref.read(
        acceptedDaySummaryProvider(request.date).future,
      );
      if (!ref.mounted) return;
      if (accepted == null) throw StateError('An accepted day is required');
      final document = await ref.read(dayDmlProvider(request.date).future);
      if (!ref.mounted) return;
      if (document == null) throw StateError('Day input is unavailable');
      final analyze = ref.read(analyzeDaySummaryUseCaseProvider);
      final result = await analyze(document, language: request.language);
      if (ref.mounted) state = AsyncData(result);
    } catch (error, stack) {
      final failure = error is LlmRequestException
          ? error.failure.name
          : 'unknown';
      logE(
        'Day AI failed: type=${error.runtimeType}, failure=$failure',
        stackTrace: stack,
      );
      if (ref.mounted) state = AsyncError(error, stack);
    }
  }
}
