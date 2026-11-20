import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logger/logger.dart';
import '../../../foreground/event/internal/aaps_carbs_request_snoozed_event.dart';
import '../data/repositories/aaps_carbs_request_episode_store.dart';

Future<void> snoozeAapsCarbsRequest({DateTime? at}) async {
  final now = clock.now();
  final answeredAt = at ?? now;
  if (!now.isBefore(answeredAt.add(const Duration(minutes: 5)))) return;
  try {
    const store = SharedPreferencesAapsCarbsRequestEpisodeStore(
      loadPreferences: SharedPreferences.getInstance,
    );
    final episode = await store.load();
    final statusAt = episode.lastAcceptedStatusAt;
    if (episode.id == null ||
        episode.acknowledged ||
        (episode.activeCarbsReq ?? 0) <= 0 ||
        statusAt == null ||
        (statusAt.isAfter(answeredAt) &&
            !episode.matchesSuggestionAt(answeredAt)) ||
        answeredAt.difference(statusAt) > const Duration(minutes: 5)) {
      return;
    }
    await store.saveSnooze((episodeId: episode.id!, at: answeredAt));
    await const MethodChannel(
      'flutter_foreground_task/methods',
    ).invokeMethod<void>(
      'sendData',
      jsonEncode({
        'external_event': 'app_event',
        'data': {
          'app_event': AapsCarbsRequestSnoozedEvent.command,
          'data': <String, Object?>{},
        },
      }),
    );
  } catch (error) {
    Log.w(
      'AapsCarbsRequest',
      'Could not request snooze (${error.runtimeType})',
    );
  }
}
