import 'dart:async';

import 'package:clock/clock.dart';

import '../../../core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import '../meal_add_on_bolus_context.dart';
import 'meal_calculator_request.dart';
import 'meal_calculator_request_store.dart';

/// The foreground service is the only owner. Views receive projections of this state.
class MealCalculatorRequestController {
  MealCalculatorRequestController({
    required this.store,
    required this.publishWindow,
    required this.readContext,
    required this.projectExtendedConfirmation,
    required this.onError,
    this.isMealRelevant,
    this.closeWindow,
    this.onComplete,
    this.readAcceptedWizards,
    this.readExtendedReceipts,
    DateTime Function()? now,
  }) : _now = now ?? clock.now;

  final DateTime Function() _now;
  final MealCalculatorRequestStore store;
  final Future<void> Function(String, List<bool>) publishWindow;
  final Future<MealAddOnBolusContext?> Function(int) readContext;
  final Future<void> Function(int, DateTime, int, bool)
  projectExtendedConfirmation;
  final void Function(Object, StackTrace) onError;
  final Future<bool> Function(int)? isMealRelevant;
  final Future<void> Function(String)? closeWindow;
  final Future<void> Function(int)? onComplete;
  final Future<List<int>?> Function(int, DateTime, int)? readAcceptedWizards;
  final Future<List<Map<String, dynamic>>> Function(DateTime, DateTime)?
  readExtendedReceipts;
  final Map<int, int> _firstObservedAt = {};
  final Map<String, MealCalculatorRequest> _requests = {};
  Map<String, dynamic>? _latest;
  bool _disposed = false;

  void dispose() {
    _disposed = true;
  }

  Future<void> _queue = Future.value();
  bool _loaded = false;

  Future<void> _enqueue(Future<void> Function() operation) {
    if (_disposed) return Future.value();
    final result = _queue.then((_) async {
      if (_disposed) return;
      if (!_loaded) {
        _loaded = true;
        try {
          for (final row in await store.read()) {
            final request = MealCalculatorRequest.fromJson(row);
            _requests[_key(request.event, request.sessionId)] = request;
            for (final row
                in request.tracker.evidence['extendedCarbs'] as List) {
              if (row['observedAt'] case final int observed) {
                _firstObservedAt[row['at'] as int] = observed;
              }
            }
          }
        } catch (error, stack) {
          onError(error, stack);
        }
      }
      await operation();
    });
    _queue = result.catchError((Object error, StackTrace stack) {
      onError(error, stack);
    });
    return _queue;
  }

  String _key(AapsBolusSuggestionNotificationEvent event, String? id) =>
      event.mealId == null ? 'session:$id' : 'meal:${event.mealId}';

  Future<void> register(
    AapsBolusSuggestionNotificationEvent event, {
    String? sessionId,
    DateTime? openedAt,
  }) => _enqueue(() async {
    final context = event.mealId == null
        ? null
        : await readContext(event.mealId!);
    final key = _key(event, sessionId);
    final existing = _requests[key];
    final sameLogicalRequest =
        existing != null &&
        (context == null || existing.contextRequestedAt == context.requestedAt);
    final sameMealRequest =
        existing != null &&
        sameLogicalRequest &&
        event.carbs >= 0 &&
        existing.event.carbs == event.carbs &&
        existing.event.extendedCarbs == event.extendedCarbs &&
        existing.event.extendedCarbsDelayMinutes ==
            event.extendedCarbsDelayMinutes &&
        existing.event.extendedCarbsDurationMinutes ==
            event.extendedCarbsDurationMinutes;
    if (sessionId == null &&
        existing?.sessionId != null &&
        sameLogicalRequest) {
      await _evaluate(existing);
      await _save();
      return;
    }
    final previousSession = existing?.sessionId;
    if (previousSession != null && !sameLogicalRequest) {
      await closeWindow?.call(previousSession);
    }
    final request = MealCalculatorRequest(
      event: event,
      sessionId: sessionId,
      openedAt: sameMealRequest
          ? existing.openedAt
          : context?.requestedAt ?? openedAt ?? _now(),
      contextRequestedAt:
          context?.requestedAt ??
          (sameMealRequest ? existing.contextRequestedAt : null),
      evidence: sameMealRequest ? existing.tracker.evidence : null,
    );
    _requests[key] = request;
    while (_requests.length > 20) {
      _requests.remove(_requests.keys.first);
    }
    await _evaluate(request);
    await _save();
  });

  Future<void> observe(Map<String, dynamic> evidence) => _enqueue(() async {
    _latest = Map<String, dynamic>.from(evidence);
    if (evidence['extendedCarb'] case final Map carb) {
      final row = Map<String, dynamic>.from(carb);
      final at = row['at'] as int;
      row['observedAt'] = _firstObservedAt.putIfAbsent(
        at,
        () => _now().millisecondsSinceEpoch,
      );
      _latest!['extendedCarb'] = row;
      while (_firstObservedAt.length > 4096) {
        _firstObservedAt.remove(_firstObservedAt.keys.first);
      }
    }
    final hadRequests = _requests.isNotEmpty;
    for (final request in _requests.values.toList()) {
      await _evaluate(request);
    }
    if (hadRequests) await _save();
  });

  Future<void> refresh() => _enqueue(() async {
    final hadRequests = _requests.isNotEmpty;
    for (final request in _requests.values.toList()) {
      await _evaluate(request);
    }
    if (hadRequests) await _save();
  });

  Future<void> _evaluate(MealCalculatorRequest request) async {
    if (_disposed) return;
    final id = request.event.mealId;
    if (id != null && isMealRelevant != null && !await isMealRelevant!(id)) {
      _requests.remove(_key(request.event, request.sessionId));
      if (request.sessionId case final session?) {
        await closeWindow?.call(session);
      }
      return;
    }
    final context = id == null ? null : await readContext(id);
    if (_disposed) return;
    // A stale confirmation must not mutate a newer request for the same meal.
    if (request.contextRequestedAt != null &&
        context != null &&
        context.requestedAt != request.contextRequestedAt) {
      return;
    }
    final evidence = <String, dynamic>{
      ...request.tracker.evidence,
      ...?_latest,
      // Restore retained extended entries before applying the new delta.
      'extendedCarbs': request.tracker.evidence['extendedCarbs'],
    };
    if (context != null && context.requestedAt == request.contextRequestedAt) {
      request.acceptedByMeal =
          !context.awaitingBolus &&
          (context.bolusConfirmed || request.event.carbs == 0);
      request.acceptedWizardTimes =
          context.acceptedWizardKeys
              .where((key) => key.startsWith('at:'))
              .map((key) => int.tryParse(key.substring(3)))
              .whereType<int>()
              .where(
                (at) =>
                    at ~/ 1000 >=
                    request.openedAt.millisecondsSinceEpoch ~/ 1000,
              )
              .toList()
            ..sort();
      evidence['mealBolusConfirmed'] = request.acceptedByMeal;
    } else if (context == null &&
        request.contextRequestedAt != null &&
        id != null) {
      final accepted = await readAcceptedWizards?.call(
        id,
        request.openedAt,
        request.event.carbs,
      );
      if (accepted != null) {
        request.acceptedByMeal = accepted.isNotEmpty;
        request.acceptedWizardTimes = accepted;
      }
      final submissions = (evidence['submissions'] as List).cast<Map>();
      evidence['mealBolusConfirmed'] =
          request.acceptedByMeal &&
          !request.acceptedWizardTimes.any(
            (at) => submissions.any(
              (row) =>
                  row['at'] == at &&
                  (row['valid'] != true || row['complete'] != true),
            ),
          );
    }
    if (request.acceptedWizardTimes.isNotEmpty) {
      evidence['mealWizardAt'] = request.acceptedWizardTimes.last;
    }
    if (request.event.carbs < 0 && readExtendedReceipts != null) {
      final receipts = await readExtendedReceipts!(
        request.openedAt,
        request.openedAt.add(const Duration(minutes: 20)),
      );
      evidence['extendedCarbs'] = [
        ...receipts,
        ...request.tracker.evidence['extendedCarbs'] as List,
      ];
    }
    if (request.event.extendedCarbs > 0 &&
        readExtendedReceipts != null &&
        request.event.extendedCarbsDelayMinutes != null) {
      final anchor =
          evidence['mealWizardAt'] as int? ??
          request.openedAt.millisecondsSinceEpoch;
      final expected = DateTime.fromMillisecondsSinceEpoch(
        anchor,
      ).add(Duration(minutes: request.event.extendedCarbsDelayMinutes!));
      final receipts = await readExtendedReceipts!(
        expected.subtract(const Duration(minutes: 2)),
        expected.add(const Duration(minutes: 2)),
      );
      evidence['extendedCarbs'] = [
        ...receipts,
        // Live invalidations retained by the owner override stale mirror rows.
        ...request.tracker.evidence['extendedCarbs'] as List,
      ];
    }
    final complete = request.tracker.update(evidence);
    if (!complete) request.instructionNotificationCleared = false;
    if (id != null &&
        context != null &&
        request.contextRequestedAt != null &&
        request.event.extendedCarbs > 0) {
      await projectExtendedConfirmation(
        id,
        request.contextRequestedAt!,
        request.event.extendedCarbs,
        request.tracker.extendedCarbsConfirmed,
      );
    }
    if (complete && id != null && !request.instructionNotificationCleared) {
      try {
        await onComplete?.call(id);
        request.instructionNotificationCleared = true;
      } catch (error, stack) {
        // Notification cleanup is an observer, not a gate for the visible state.
        onError(error, stack);
      }
    }
    if (_disposed) return;
    if (request.sessionId case final session?) {
      await publishWindow(session, request.completedRows);
    }
  }

  Future<void> _save() {
    if (_disposed) return Future.value();
    return store.write(
      _requests.values.map((request) => request.toJson()).toList(),
    );
  }
}
