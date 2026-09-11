import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/day_summary_provider.dart';
import '../../domain/models/accepted_day_summary.dart';
import '../../domain/models/day_summary_snapshot.dart';
import '../../domain/use_cases/accept_day_summary_use_case.dart';

final daySummaryControllerProvider = AsyncNotifierProvider.autoDispose
    .family<DaySummaryController, void, DateTime>(DaySummaryController.new);

class DaySummaryController extends AsyncNotifier<void> {
  final DateTime date;
  DaySummaryController(this.date);

  @override
  FutureOr<void> build() {}

  Future<AcceptedDaySummary> confirm(
    DaySummarySnapshot preview, {
    required Set<int> skippedRecords,
    required bool acknowledgeLimitations,
  }) async {
    if (state.isLoading) throw StateError('Acceptance is already in progress');
    final keepAlive = ref.keepAlive();
    final accept = AcceptDaySummaryUseCase(
      loadCurrent: () => ref.read(daySummaryDraftProvider(date).future),
      save: ref.read(daySummaryRepositoryProvider).insert,
      now: clock.now,
    );
    state = const AsyncLoading();
    try {
      final result = await accept(
        preview,
        skippedRecords: Set.of(skippedRecords),
        acknowledgeLimitations: acknowledgeLimitations,
      );
      if (ref.mounted) {
        ref.invalidate(acceptedDaySummaryProvider(date));
        state = const AsyncData(null);
      }
      return result;
    } catch (error, stack) {
      if (ref.mounted) state = AsyncError(error, stack);
      rethrow;
    } finally {
      keepAlive.close();
    }
  }
}
