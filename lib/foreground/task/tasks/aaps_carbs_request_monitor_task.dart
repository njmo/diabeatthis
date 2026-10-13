import 'dart:async';

import 'package:clock/clock.dart';

import '../../../core/domain/model/glucose.dart';
import '../../../core/logger/logger.dart';
import '../../../core/notifications/domain/events/aaps_carbs_request_notification.dart';
import '../../../core/notifications/domain/models/hash_notification_id_factory.dart';
import '../../../core/notifications/domain/models/notification_event_type.dart';
import '../../../core/notifications/domain/models/notification_key.dart';
import '../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../features/low_treatment/data/providers/aaps_carbs_request_episode_store_provider.dart';
import '../../../features/low_treatment/data/repositories/aaps_carbs_request_episode_store.dart';
import '../../../features/low_treatment/domain/models/aaps_carbs_request_episode.dart';
import '../../../features/low_treatment/domain/models/aaps_carbs_request_signal.dart';
import '../../../features/low_treatment/domain/use_cases/evaluate_aaps_carbs_request_use_case.dart';
import '../../event/internal/aaps_carbs_request_acknowledged_event.dart';
import '../../event/model/foreground_event.dart';
import '../../runtime/event_inbox.dart';
import '../../runtime/task_cancelled_exception.dart';
import '../../synchronization/synchronization_cache_controller.dart';
import '../base/runtime_context.dart';
import '../base/workflow_task.dart';

class AapsCarbsRequestMonitorTask extends WorkflowTask with Logging {
  static const reminderInterval = Duration(minutes: 5);
  static const failureRetryInterval = Duration(seconds: 5);
  static const _notificationKey = NotificationKey(
    type: NotificationEventType.aapsCarbsRequest,
    entityId: 0,
  );

  const AapsCarbsRequestMonitorTask();

  @override
  Future<void> run(RuntimeContext context) async {
    final inbox = context.openEventInbox<ForegroundEvent>();
    final store = context.container.read(aapsCarbsRequestEpisodeStoreProvider);
    AapsCarbsRequestEpisode? episode;
    var firstLoad = true;
    final pendingAcknowledgements = <AapsCarbsRequestAcknowledgedEvent>[];

    try {
      while (!context.isCancelled) {
        if (episode == null) {
          try {
            episode = await store.load();
            episode = await _cancelPending(context, episode, store);
            if (firstLoad) {
              episode = await _hideUnavailable(context, episode);
              firstLoad = false;
            }
          } on TaskCancelledException {
            rethrow;
          } catch (error) {
            episode = null;
            context.log(
              'AAPS carbs reminder initialization failed: '
              '${error.runtimeType}',
            );
            await context.waitForDuration(failureRetryInterval);
            continue;
          }
        }

        final eventWake = context.eventWait<ForegroundEvent>();
        eventWake.future.ignore();
        Object? failure;
        try {
          try {
            episode = await _applyEvents(
              inbox,
              pendingAcknowledgements,
              episode,
              store,
              context,
            );
            episode = await _evaluateAndNotify(
              context,
              episode,
              store,
              inbox,
              pendingAcknowledgements,
            );
          } on TaskCancelledException {
            rethrow;
          } catch (error) {
            failure = error;
          }
          if (failure == null) {
            final deadline = context.durationWait(
              _waitDuration(context, episode!, clock.now()),
            );
            try {
              await Future.any<void>([
                eventWake.future.then<void>((_) {}),
                deadline.future,
              ]);
            } finally {
              await deadline.cancel();
            }
          }
        } finally {
          await eventWake.cancel();
        }
        if (failure != null) {
          context.log(
            'AAPS carbs reminder operation failed: ${failure.runtimeType}',
          );
          episode = null;
          await context.waitForDuration(failureRetryInterval);
        }
      }
    } finally {
      inbox.close();
    }
  }

  Future<AapsCarbsRequestEpisode> _evaluateAndNotify(
    RuntimeContext context,
    AapsCarbsRequestEpisode episode,
    AapsCarbsRequestEpisodeStore store,
    EventInbox<ForegroundEvent> inbox,
    List<AapsCarbsRequestAcknowledgedEvent> pendingAcknowledgements,
  ) async {
    final now = clock.now();
    var evaluation = await _acceptedSignal(context, episode, store, now);
    var signal = evaluation.signal;
    episode = evaluation.episode;
    if (signal.type == AapsCarbsRequestSignalType.withdrawn) {
      return _withdraw(context, episode, store);
    }
    if (signal.type != AapsCarbsRequestSignalType.positive) {
      return _hideUnavailable(context, episode);
    }

    if (episode.id == null) {
      final status = signal.status!;
      final requestAt = status.suggestedAt ?? status.date;
      final id =
          '${requestAt.microsecondsSinceEpoch}:${status.externalId ?? ''}';
      await store.start(id);
      episode = episode.start(id);
    }
    if (episode.acknowledged || !_isDue(episode, now)) return episode;

    episode = await _applyEvents(
      inbox,
      pendingAcknowledgements,
      episode,
      store,
      context,
    );
    final checkedAt = clock.now();
    evaluation = await _acceptedSignal(context, episode, store, checkedAt);
    signal = evaluation.signal;
    episode = evaluation.episode;
    if (signal.type == AapsCarbsRequestSignalType.withdrawn) {
      return _withdraw(context, episode, store);
    }
    if (signal.type != AapsCarbsRequestSignalType.positive) {
      return _hideUnavailable(context, episode);
    }
    if (episode.acknowledged || !_isDue(episode, checkedAt)) {
      return episode;
    }

    final requestAt = signal.status!.suggestedAt ?? signal.status!.date;
    if (episode.lastReminderAt != null &&
        !requestAt.isAfter(episode.lastReminderAt!)) {
      return _hideUnavailable(context, episode);
    }

    await context.container
        .read(notificationsControllerForegroundProvider)
        .show(
          AapsCarbsRequestNotificationEvent(
            episodeId: episode.id!,
            carbs: signal.status!.carbsReq,
          ),
        );
    await store.markReminded(checkedAt);
    return episode.reminded(checkedAt);
  }

  Future<({AapsCarbsRequestSignal signal, AapsCarbsRequestEpisode episode})>
  _acceptedSignal(
    RuntimeContext context,
    AapsCarbsRequestEpisode episode,
    AapsCarbsRequestEpisodeStore store,
    DateTime now,
  ) async {
    final signal = _signal(context, now);
    // Track newer incomplete results too: an older positive result must not
    // become current again after a status with missing suggestion data.
    final status = context.container
        .read(synchronizationCacheControllerProvider)
        .cache
        .deviceStatusCache;
    if (status == null) return (signal: signal, episode: episode);

    final statusAt = status.suggestedAt ?? status.date;
    if (statusAt.isAfter(now)) return (signal: signal, episode: episode);
    final watermark = episode.lastAcceptedStatusAt;
    if (watermark != null && statusAt.isBefore(watermark)) {
      return (
        signal: const AapsCarbsRequestSignal.unavailable(),
        episode: episode,
      );
    }
    if (signal.type == AapsCarbsRequestSignalType.positive &&
        episode.activeCarbsReq != null &&
        status.carbsReq != episode.activeCarbsReq) {
      await _hideUnavailable(context, episode);
    }
    if (watermark == null || statusAt.isAfter(watermark)) {
      final activeCarbsReq = signal.type == AapsCarbsRequestSignalType.positive
          ? status.carbsReq
          : null;
      await store.acceptStatus(statusAt, activeCarbsReq);
      episode = episode.acceptStatus(statusAt, activeCarbsReq);
    }
    return (signal: signal, episode: episode);
  }

  AapsCarbsRequestSignal _signal(RuntimeContext context, DateTime now) {
    final cache = context.container
        .read(synchronizationCacheControllerProvider)
        .cache;
    return const EvaluateAapsCarbsRequestUseCase()(
      status: cache.deviceStatusCache,
      glucose: cache.glucoseReadingsCache,
      now: now,
    );
  }

  Future<AapsCarbsRequestEpisode> _applyEvents(
    EventInbox<ForegroundEvent> inbox,
    List<AapsCarbsRequestAcknowledgedEvent> pending,
    AapsCarbsRequestEpisode episode,
    AapsCarbsRequestEpisodeStore store,
    RuntimeContext context,
  ) async {
    pending.addAll(
      inbox.drain().whereType<AapsCarbsRequestAcknowledgedEvent>(),
    );
    while (pending.isNotEmpty) {
      final event = pending.first;
      final id =
          event.episodeId ??
          (episode.matchesSuggestionAt(event.suggestionAt) ? episode.id : null);
      if (id == null || id != episode.id) {
        pending.removeAt(0);
        continue;
      }
      await store.acknowledge(id);
      pending.removeAt(0);
      episode = episode.acknowledge(id);
      episode = await _cancelPending(context, episode, store);
    }
    return episode;
  }

  bool _isDue(AapsCarbsRequestEpisode episode, DateTime now) {
    final last = episode.lastReminderAt;
    return last == null || !now.isBefore(last.add(reminderInterval));
  }

  Duration _waitDuration(
    RuntimeContext context,
    AapsCarbsRequestEpisode episode,
    DateTime now,
  ) {
    var wait = reminderInterval;
    final cache = context.container
        .read(synchronizationCacheControllerProvider)
        .cache;
    final statusAt =
        cache.deviceStatusCache?.suggestedAt ?? cache.deviceStatusCache?.date;
    final glucoseTimes = cache.glucoseReadingsCache
        .where(
          (g) => g.type == GlucoseType.cgm && g.sgv > 0 && !g.date.isAfter(now),
        )
        .map((g) => g.date);
    DateTime? latestGlucose;
    for (final at in glucoseTimes) {
      if (latestGlucose == null || at.isAfter(latestGlucose)) {
        latestGlucose = at;
      }
    }
    // Expiration must hide the notification even when no new event arrives.
    for (final at in [statusAt, latestGlucose].whereType<DateTime>()) {
      final remaining = at
          .add(EvaluateAapsCarbsRequestUseCase.maximumAge)
          .difference(now);
      if (remaining > Duration.zero && remaining < wait) wait = remaining;
    }
    final last = episode.lastReminderAt;
    if (!episode.acknowledged && last != null) {
      final remaining = last.add(reminderInterval).difference(now);
      if (remaining > Duration.zero && remaining < wait) wait = remaining;
    }
    return wait;
  }

  Future<AapsCarbsRequestEpisode> _hideUnavailable(
    RuntimeContext context,
    AapsCarbsRequestEpisode episode,
  ) async {
    // Keep acknowledgement and matching identity; missing data is not withdrawal.
    if (!episode.acknowledged && episode.lastReminderAt != null) {
      await _cancelNotification(context);
    }
    return episode;
  }

  Future<void> _cancelNotification(RuntimeContext context) {
    final id = const HashNotificationIdFactory().create(_notificationKey);
    return context.container
        .read(notificationsControllerForegroundProvider)
        .cancel(id);
  }

  Future<AapsCarbsRequestEpisode> _withdraw(
    RuntimeContext context,
    AapsCarbsRequestEpisode episode,
    AapsCarbsRequestEpisodeStore store,
  ) async {
    if (episode.id == null) return episode;
    await store.clear();
    final cleared = episode.clear();
    return _cancelPending(context, cleared, store);
  }

  Future<AapsCarbsRequestEpisode> _cancelPending(
    RuntimeContext context,
    AapsCarbsRequestEpisode episode,
    AapsCarbsRequestEpisodeStore store,
  ) async {
    if (!episode.notificationCancellationPending) return episode;
    await _cancelNotification(context);
    await store.markNotificationCancelled();
    return episode.cancelled();
  }
}
