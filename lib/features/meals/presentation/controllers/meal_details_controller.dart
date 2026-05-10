import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/domain/use_cases/analyze_meal_use_case.dart';
import '../../data/domain/use_cases/load_meal_details_use_case.dart';
import '../models/meal_page_state.dart';

part 'meal_details_controller.g.dart';

@riverpod
class MealDetailsControllerNotifier extends _$MealDetailsControllerNotifier {
  @override
  Future<MealPageState> build(int mealId) async {
    final detailsUseCase = ref.read(loadMealDetailsUseCaseProvider);
    final details = await detailsUseCase.call(mealId);

    final analysisUseCase = ref.read(analyzeMealUseCaseProvider);
    try {
      final analysis = await analysisUseCase.call(details);
      return MealPageState(details: details, analysis: analysis);
    } catch (error) {
      return MealPageState(details: details, analysisError: error.toString());
    }
  }

  void setDetailedMode(bool value) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(detailedMode: value));
  }

  void setShowRawTechnicalData(bool value) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(showRawTechnicalData: value));
  }

  void selectTimestamp(DateTime timestamp) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(selectedTimestamp: timestamp));
  }

  void clearSelectedTimestamp() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(clearSelectedTimestamp: true));
  }

  void zoomTimeline(double factor) {
    final current = state.value;
    final analysis = current?.analysis;
    if (current == null || analysis == null) return;

    final viewport = _currentViewport(current);
    final currentDuration = viewport.end.difference(viewport.start);
    final nextDuration = Duration(
      milliseconds: (currentDuration.inMilliseconds * factor).round(),
    );
    final clampedDuration = _clampDuration(
      nextDuration,
      const Duration(minutes: 20),
      analysis.chartEnd.difference(analysis.chartStart),
    );
    final anchor =
        current.selectedTimestamp ?? _midpoint(viewport.start, viewport.end);
    final start = anchor.subtract(clampedDuration ~/ 2);
    final end = anchor.add(clampedDuration ~/ 2);
    _setViewport(current, start, end);
  }

  void panTimeline(Duration delta) {
    final current = state.value;
    final analysis = current?.analysis;
    if (current == null || analysis == null) return;

    final viewport = _currentViewport(current);
    _setViewport(current, viewport.start.add(delta), viewport.end.add(delta));
  }

  void resetTimelineViewport() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(clearViewport: true));
  }

  ({DateTime start, DateTime end}) _currentViewport(MealPageState current) {
    final analysis = current.analysis;
    if (analysis == null) {
      final now = DateTime.now();
      return (start: now, end: now);
    }
    return (
      start: current.visibleStart ?? analysis.chartStart,
      end: current.visibleEnd ?? analysis.chartEnd,
    );
  }

  void _setViewport(
    MealPageState current,
    DateTime requestedStart,
    DateTime requestedEnd,
  ) {
    final analysis = current.analysis;
    if (analysis == null) return;

    final fullStart = analysis.chartStart;
    final fullEnd = analysis.chartEnd;
    final fullDuration = fullEnd.difference(fullStart);
    var duration = requestedEnd.difference(requestedStart);
    duration = _clampDuration(
      duration,
      const Duration(minutes: 20),
      fullDuration,
    );

    var start = requestedStart;
    var end = start.add(duration);
    if (start.isBefore(fullStart)) {
      start = fullStart;
      end = start.add(duration);
    }
    if (end.isAfter(fullEnd)) {
      end = fullEnd;
      start = end.subtract(duration);
    }

    state = AsyncData(current.copyWith(visibleStart: start, visibleEnd: end));
  }

  Duration _clampDuration(Duration value, Duration min, Duration max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  DateTime _midpoint(DateTime start, DateTime end) {
    return start.add(end.difference(start) ~/ 2);
  }
}
