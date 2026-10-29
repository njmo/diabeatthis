import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../common/events/data/notification/temp_target_type.dart';
import '../../../../common/temporary_targets/owned_temp_target.dart';
import '../../../../common/temporary_targets/temp_target_operation.dart';
import '../../../../common/temporary_targets/temp_target_policy.dart';
import '../../../../common/temporary_targets/temp_target_proposal.dart';
import '../../../../common/temporary_targets/temp_target_request_id.dart';
import '../../../data/provider/shared_prefs_provider.dart';
import '../../../domain/model/temporary_target.dart';
import '../../../drift/database_impl.dart'
    hide TempTargetOperation, TemporaryTarget;
import '../../../drift/providers/database_provider.dart';
import '../../../logger/logger.dart';
import '../../../notifications/domain/events/temp_target_notification.dart';
import '../nightscout_storage_keys.dart';
import 'nightscout_temp_target_write_exception.dart';
import 'nightscout_temp_target_writer.dart';
import 'temp_target_legacy_migration.dart';
import 'temp_target_operation_reconciler.dart';
import 'temp_target_operation_repository.dart';

final tempTargetServiceProvider = Provider<TempTargetService>(
  (ref) => TempTargetService(
    preferences: () => ref.read(sharedPrefsProvider.future),
    database: () => ref.read(databaseProvider),
    writer: NightscoutTempTargetWriter(),
  ),
);

enum TempTargetSendResult { ignored, sent, failed, expired, deferred }

class TempTargetService with Logging {
  TempTargetService({
    required this.preferences,
    required this.database,
    required this.writer,
  });

  final Future<SharedPreferences> Function() preferences;
  final DatabaseImpl Function() database;
  final NightscoutTempTargetWriter writer;
  final Set<String> _processing = {};
  final Map<String, DateTime> _presenting = {};
  bool _sending = false;
  DateTime? _lastRecoveryAt;
  String? _lastRecoverySource;

  Future<SharedPreferences> _preferences() async {
    final prefs = await preferences();
    await prefs.reload();
    return prefs;
  }

  bool isEnabled(SharedPreferences prefs) =>
      prefs.getBool(nightscoutTempTargetsEnabledKey) == true &&
      (prefs.getString(nightscoutTokenKey)?.trim().isNotEmpty ?? false) &&
      (prefs.getString(nightscoutUrlKey)?.trim().isNotEmpty ?? false);

  String _source(SharedPreferences prefs) =>
      prefs.getString(nightscoutUrlKey)?.trim() ?? '';

  Future<TempTargetOperationRepository> _operations(
    SharedPreferences prefs,
  ) async {
    final operations = TempTargetOperationRepository(database());
    await TempTargetLegacyMigration(operations).migrate(prefs);
    return operations;
  }

  Future<void> _recover(
    TempTargetOperationRepository operations,
    SharedPreferences prefs,
  ) async {
    if (_sending) return;
    final source = _source(prefs);
    if (!(await operations.unresolvedSends()).any(
      (op) => op.source == source,
    )) {
      return;
    }
    if (_lastRecoverySource == source &&
        _lastRecoveryAt != null &&
        clock.now().difference(_lastRecoveryAt!) < const Duration(minutes: 1)) {
      return;
    }
    _lastRecoveryAt = clock.now();
    _lastRecoverySource = source;
    await TempTargetOperationReconciler(
      operations,
      writer,
    ).reconcile(source, prefs.getString(nightscoutTokenKey) ?? '');
  }

  TempTargetNotificationEvent _notification(TempTargetProposal proposal) =>
      TempTargetNotificationEvent(
        entityId: proposal.entityId,
        targetType: proposal.targetType,
        requestId: proposal.id,
        target: proposal.target,
        durationMinutes: proposal.durationAt(clock.now()),
        renewal: proposal.renewal,
      );

  TempTargetNotificationEvent? _pendingNotification(
    TempTargetOperation operation,
  ) {
    final proposal = operation.proposal;
    if (operation.status != TempTargetOperationStatus.pendingDelivery ||
        proposal == null ||
        !proposal.expiresAt.isAfter(clock.now())) {
      return null;
    }
    final presentingAt = _presenting[proposal.id];
    if (presentingAt != null &&
        clock.now().difference(presentingAt) < const Duration(minutes: 1)) {
      return null;
    }
    // This short in-memory lease suppresses competing monitor passes. Only a
    // successful platform show acknowledges delivery durably.
    _presenting[proposal.id] = clock.now();
    return _notification(proposal);
  }

  Future<void> markDelivered(String requestId) async {
    await TempTargetOperationRepository(database()).markDelivered(requestId);
    _presenting.remove(requestId);
  }

  void deliveryFailed(String requestId) => _presenting.remove(requestId);

  /// Legacy prompts remain reminders. Only newly issued offers authorize writes.
  Future<TempTargetNotificationEvent?> prepare(
    TempTargetNotificationEvent event,
  ) async {
    final prefs = await _preferences();
    if (event.requestId != null) return isEnabled(prefs) ? event : null;
    if (!isEnabled(prefs)) return event;
    // ActivityMonitorTask owns activity offers in write mode.
    if (event.targetType != TempTargetType.meal) return null;
    final meal = await database().mealDao.getMealById(event.entityId);
    if (meal == null || meal.status != 'planned') return null;
    final operations = await _operations(prefs);
    await _recover(operations, prefs);
    final existing = await operations.latestStart(
      entityId: event.entityId,
      targetType: event.targetType,
      source: _source(prefs),
    );
    if (existing != null &&
        existing.status != TempTargetOperationStatus.rejected) {
      return _pendingNotification(existing);
    }
    final now = clock.now();
    return _pendingNotification(
      await operations.createOffer(
        TempTargetProposal(
          id: TempTargetRequestId.create(
            TempTargetType.meal,
            event.entityId,
            now,
          ),
          entityId: event.entityId,
          targetType: TempTargetType.meal,
          target: TempTargetPolicy.mealTarget,
          durationMinutes: TempTargetPolicy.mealDuration,
          expiresAt: now.add(const Duration(minutes: 15)),
          source: _source(prefs),
        ),
      ),
    );
  }

  /// Recovers meal prompts whose platform delivery was interrupted or failed.
  Future<List<TempTargetNotificationEvent>> pendingMealOffers() async {
    final prefs = await _preferences();
    if (!isEnabled(prefs)) return [];
    final operations = await _operations(prefs);
    final pending = await operations.list(
      statuses: {
        TempTargetOperationStatus.pendingDelivery,
        TempTargetOperationStatus.rejected,
      },
      kind: TempTargetOperationKind.start,
    );
    final result = <TempTargetNotificationEvent>[];
    for (final operation in pending) {
      if (operation.source != _source(prefs) ||
          operation.targetType != TempTargetType.meal) {
        continue;
      }
      final meal = await database().mealDao.getMealById(operation.entityId);
      if (meal == null || meal.status != 'planned') continue;
      final event = operation.status == TempTargetOperationStatus.rejected
          ? await prepare(
              TempTargetNotificationEvent.meal(entityId: operation.entityId),
            )
          : _pendingNotification(operation);
      if (event != null) result.add(event);
    }
    return result;
  }

  /// A persisted pending prompt can be redelivered after a restart or show error.
  Future<TempTargetNotificationEvent?> activityOffer(
    int activityLogId, {
    TemporaryTarget? activeTarget,
  }) async {
    final prefs = await _preferences();
    if (!isEnabled(prefs)) return null;
    final db = database();
    final log = await db.activityDao.getActivityLogByIdOrNull(activityLogId);
    if (log == null || log.endedAt != null) return null;
    final now = clock.now();
    final startsAt = DateTime.fromMillisecondsSinceEpoch(log.startedAt);
    if (now.isBefore(startsAt.subtract(TempTargetPolicy.activityLeadTime))) {
      return null;
    }
    final activity = await db.activityDao.getActivityById(log.activityId);
    final duration = await db.activityDao.getEffectiveDurationForLog(
      log.id,
      activity.durationMinutes,
    );
    final endsAt = duration == null || duration <= 0
        ? null
        : startsAt.add(Duration(minutes: duration));
    if (endsAt != null && !endsAt.isAfter(now)) return null;
    final operations = await _operations(prefs);
    await _recover(operations, prefs);
    if ((await operations.unresolvedSends()).any(
      (op) => op.source == _source(prefs),
    )) {
      return null;
    }
    final observedEnd = activeTarget?.createdAt.add(
      Duration(minutes: activeTarget.duration),
    );
    final matchingTarget =
        activeTarget != null &&
        activeTarget.isValid &&
        TempTargetPolicy.acceptsActivityTargetValue(activeTarget.targetTop) &&
        !activeTarget.createdAt.isAfter(now) &&
        observedEnd!.isAfter(now);
    if (matchingTarget && endsAt != null && !observedEnd.isBefore(endsAt)) {
      return null;
    }

    final previous = await operations.list(kind: TempTargetOperationKind.start);
    final coverage =
        previous
            .where(
              (op) =>
                  op.entityId == log.id &&
                  op.targetType == TempTargetType.activity &&
                  op.source == _source(prefs) &&
                  op.confirmedTarget != null,
            )
            .map((op) => op.confirmedTarget!.until)
            .toList()
          ..sort();
    var sentUntil = coverage.lastOrNull;
    // The pre-migration observation was advisory coverage, never ownership.
    final legacyState = prefs.getString('temp_target_activity_state_${log.id}');
    if (sentUntil == null && legacyState != null) {
      final state = jsonDecode(legacyState) as Map<String, dynamic>;
      if (state['source'] == _source(prefs)) {
        sentUntil = DateTime.tryParse(state['until'] as String? ?? '');
      }
    }
    if (matchingTarget &&
        (sentUntil == null || observedEnd.isAfter(sentUntil))) {
      sentUntil = observedEnd;
    }
    final initialManualEnd = startsAt.add(
      TempTargetPolicy.initialManualActivityCoverage,
    );
    if (sentUntil != null) {
      if (endsAt != null && !sentUntil.isBefore(endsAt)) return null;
      final leadTime =
          endsAt == null &&
              !sentUntil.isAfter(
                initialManualEnd.add(const Duration(minutes: 1)),
              )
          ? Duration.zero
          : TempTargetPolicy.renewalLeadTime;
      if (now.isBefore(sentUntil.subtract(leadTime))) return null;
    }
    final initialManual =
        endsAt == null && sentUntil == null && initialManualEnd.isAfter(now);
    final coverageEnd = endsAt ?? (initialManual ? initialManualEnd : null);
    final generation = sentUntil?.millisecondsSinceEpoch ?? 0;
    final existing = await operations.latestStart(
      entityId: log.id,
      targetType: TempTargetType.activity,
      source: _source(prefs),
    );
    if (existing?.proposal case final proposal?) {
      if (proposal.coverageGeneration == generation &&
          proposal.hasSameEnd(endsAt) &&
          existing!.status != TempTargetOperationStatus.rejected &&
          existing.status != TempTargetOperationStatus.completed) {
        return _pendingNotification(existing);
      }
    }
    final proposal = TempTargetProposal(
      id: TempTargetRequestId.create(TempTargetType.activity, log.id, now),
      entityId: log.id,
      targetType: TempTargetType.activity,
      target: TempTargetPolicy.activityTarget,
      durationMinutes: coverageEnd == null
          ? TempTargetPolicy.manualActivityDuration
          : TempTargetPolicy.minutesUntil(now, coverageEnd),
      expiresAt:
          coverageEnd ??
          (sentUntil != null && sentUntil.isAfter(now)
              ? sentUntil
              : now.add(const Duration(minutes: 15))),
      endsAt: endsAt,
      durationEndsAt: initialManual ? initialManualEnd : null,
      renewal:
          sentUntil != null ||
          (endsAt == null && !initialManualEnd.isAfter(now)),
      coverageGeneration: generation,
      source: _source(prefs),
    );
    return _pendingNotification(await operations.createOffer(proposal));
  }

  Future<TempTargetSendResult> respond({
    required String requestId,
    required String targetType,
    required int entityId,
    required bool approved,
  }) async {
    if (!_processing.add(requestId)) return TempTargetSendResult.ignored;
    var ownsSend = false;
    try {
      final prefs = await _preferences();
      final operations = await _operations(prefs);
      final operation = await operations.get(requestId);
      final proposal = operation?.proposal;
      if (proposal == null ||
          proposal.targetType != targetType ||
          proposal.entityId != entityId ||
          !{
            TempTargetOperationStatus.pendingDelivery,
            TempTargetOperationStatus.awaitingConsent,
          }.contains(operation!.status)) {
        return TempTargetSendResult.ignored;
      }
      final latest = await operations.latestStart(
        entityId: entityId,
        targetType: targetType,
        source: proposal.source,
      );
      if (latest?.requestId != requestId) return TempTargetSendResult.ignored;
      if (!approved) {
        await operations.decline(requestId);
        return TempTargetSendResult.ignored;
      }
      if (!isEnabled(prefs) || proposal.source != _source(prefs)) {
        return TempTargetSendResult.expired;
      }
      await _recover(operations, prefs);
      final now = clock.now();
      if (!proposal.expiresAt.isAfter(now) || proposal.durationAt(now) <= 0) {
        return TempTargetSendResult.expired;
      }
      final db = database();
      if (targetType == TempTargetType.activity) {
        final log = await db.activityDao.getActivityLogByIdOrNull(entityId);
        if (log == null || log.endedAt != null) {
          return TempTargetSendResult.expired;
        }
        final activity = await db.activityDao.getActivityById(log.activityId);
        final duration = await db.activityDao.getEffectiveDurationForLog(
          log.id,
          activity.durationMinutes,
        );
        final currentEnd = duration == null || duration <= 0
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                log.startedAt,
              ).add(Duration(minutes: duration));
        if (!proposal.hasSameEnd(currentEnd)) {
          return TempTargetSendResult.expired;
        }
      } else {
        final meal = await db.mealDao.getMealById(entityId);
        if (meal == null || meal.status != 'planned') {
          return TempTargetSendResult.expired;
        }
      }
      if (_sending) return await _deferApproval(operations, requestId);
      final attempted = OwnedTempTarget(
        entityId: entityId,
        targetType: targetType,
        source: proposal.source,
        startedAt: now,
        until: now.add(Duration(minutes: proposal.durationAt(now))),
        target: proposal.target,
        durationMinutes: proposal.durationAt(now),
      );
      if (!await operations.claimStart(requestId, attempted)) {
        return await _deferApproval(operations, requestId);
      }
      _sending = true;
      ownsSend = true;
      try {
        final nightscoutId = await writer.send(
          url: proposal.source,
          token: prefs.getString(nightscoutTokenKey) ?? '',
          startsAt: now,
          target: proposal.target,
          durationMinutes: attempted.durationMinutes,
          reason: targetType == TempTargetType.activity
              ? 'Activity'
              : 'Eating Soon',
        );
        await operations.markSent(
          requestId,
          confirmed: attempted.withNightscoutId(nightscoutId),
        );
        return TempTargetSendResult.sent;
      } catch (error) {
        await _recordFailure(operations, requestId, error);
        return TempTargetSendResult.failed;
      }
    } catch (error) {
      logW('Temporary target response failed: ${error.runtimeType}');
      return TempTargetSendResult.failed;
    } finally {
      if (ownsSend) _sending = false;
      _presenting.remove(requestId);
      _processing.remove(requestId);
    }
  }

  Future<TempTargetSendResult> _deferApproval(
    TempTargetOperationRepository operations,
    String requestId,
  ) async => await operations.deferConsent(requestId)
      ? TempTargetSendResult.deferred
      : TempTargetSendResult.ignored;

  Future<void> _recordFailure(
    TempTargetOperationRepository operations,
    String id,
    Object error,
  ) async {
    if (error is NightscoutTempTargetWriteException &&
        error.isDefinitiveRejection) {
      await operations.markRejected(id);
    } else {
      await operations.markUnknownResult(id);
    }
    logW('Temporary target upload failed: ${error.runtimeType}');
  }

  /// Uses the actual closure timestamp, preserving later manual replacements.
  Future<TempTargetSendResult> stopFinishedActivityTarget() async {
    if (_sending) return TempTargetSendResult.ignored;
    final prefs = await _preferences();
    if (!isEnabled(prefs)) return TempTargetSendResult.ignored;
    final operations = await _operations(prefs);
    await _recover(operations, prefs);
    final operation = await operations.latestOwnedOperation(
      source: _source(prefs),
    );
    final owned = operation?.confirmedTarget;
    if (owned == null || owned.targetType != TempTargetType.activity) {
      return TempTargetSendResult.ignored;
    }
    final log = await database().activityDao.getActivityLogByIdOrNull(
      owned.entityId,
    );
    if (log != null && log.endedAt == null) return TempTargetSendResult.ignored;
    final closedAt =
        operation!.closedAt ??
        (log?.endedAt == null
            ? clock.now()
            : DateTime.fromMillisecondsSinceEpoch(log!.endedAt!));
    await operations.closeActivity(owned.entityId, closedAt);
    final earliestStop = owned.startedAt.add(const Duration(seconds: 1));
    final at = closedAt.isBefore(earliestStop) ? earliestStop : closedAt;
    if (!owned.until.isAfter(at)) {
      await operations.completeOwned(owned);
      return TempTargetSendResult.ignored;
    }
    final stopId = '${operation.requestId}:stop';
    final previousStop = await operations.get(stopId);
    if (previousStop != null &&
        previousStop.status != TempTargetOperationStatus.pendingDelivery) {
      return TempTargetSendResult.ignored;
    }
    if (_sending) return TempTargetSendResult.ignored;
    _sending = true;
    try {
      // AAPS coalesces starts less than a second apart. Wait out that window and
      // include its end in the ownership read before writing a historical stop.
      final guardEnd = at.add(const Duration(milliseconds: 999));
      final delay = guardEnd.difference(clock.now());
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      final token = prefs.getString(nightscoutTokenKey) ?? '';
      final latest = await writer.latest(owned.source, token, at: guardEnd);
      if (latest == null || !owned.matchesActive(latest, at)) {
        await operations.completeOwned(owned);
        return TempTargetSendResult.ignored;
      }
      final stop = await operations.createStop(
        requestId: stopId,
        owned: owned,
        stoppedAt: at,
      );
      if (!await operations.claimStop(stop.requestId)) {
        return TempTargetSendResult.ignored;
      }
      try {
        await writer.stop(url: owned.source, token: token, at: at);
        await operations.markSent(stop.requestId);
        return TempTargetSendResult.sent;
      } catch (error) {
        await _recordFailure(operations, stop.requestId, error);
        return TempTargetSendResult.failed;
      }
    } catch (_) {
      return TempTargetSendResult.failed;
    } finally {
      _sending = false;
    }
  }
}
