import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/aaps_carbs_request_episode.dart';

abstract interface class AapsCarbsRequestEpisodeStore {
  Future<AapsCarbsRequestEpisode> load();
  Future<void> start(String episodeId);
  Future<void> markReminded(DateTime at);
  Future<void> acceptStatus(DateTime at, double? activeCarbsReq);
  Future<void> acknowledge(String episodeId);
  Future<void> clear();
  Future<void> markNotificationCancelled();
}

class SharedPreferencesAapsCarbsRequestEpisodeStore
    implements AapsCarbsRequestEpisodeStore {
  static const _episodeKey = 'aaps_carbs_request_episode';

  final Future<SharedPreferences> Function() loadPreferences;

  const SharedPreferencesAapsCarbsRequestEpisodeStore({
    required this.loadPreferences,
  });

  @override
  Future<AapsCarbsRequestEpisode> load() async {
    final preferences = await loadPreferences();
    await preferences.reload();
    final encoded = preferences.getString(_episodeKey);
    if (encoded == null) return const AapsCarbsRequestEpisode.empty();
    try {
      final data = jsonDecode(encoded) as Map<String, dynamic>;
      return AapsCarbsRequestEpisode(
        id: data['id'] as String?,
        acknowledged: data['acknowledged'] as bool? ?? false,
        lastReminderAt: _date(data['lastReminderAt']),
        lastAcceptedStatusAt: _date(data['lastAcceptedStatusAt']),
        activeCarbsReq: (data['activeCarbsReq'] as num?)?.toDouble(),
        notificationCancellationPending:
            data['notificationCancellationPending'] as bool? ?? false,
      );
    } on FormatException {
      return const AapsCarbsRequestEpisode.empty();
    } on TypeError {
      return const AapsCarbsRequestEpisode.empty();
    }
  }

  @override
  Future<void> start(String episodeId) async {
    final current = await load();
    await _write(current.start(episodeId));
  }

  @override
  Future<void> markReminded(DateTime at) async {
    final current = await load();
    if (current.id == null) return;
    await _write(current.reminded(at));
  }

  @override
  Future<void> acceptStatus(DateTime at, double? activeCarbsReq) async {
    final current = await load();
    await _write(current.acceptStatus(at, activeCarbsReq));
  }

  @override
  Future<void> acknowledge(String episodeId) async {
    final current = await load();
    if (current.id != episodeId) return;
    await _write(current.acknowledge(episodeId));
  }

  @override
  Future<void> clear() async {
    final current = await load();
    await _write(current.clear());
  }

  @override
  Future<void> markNotificationCancelled() async {
    final current = await load();
    await _write(current.cancelled());
  }

  Future<void> _write(AapsCarbsRequestEpisode episode) async {
    final preferences = await loadPreferences();
    final encoded = jsonEncode({
      'id': episode.id,
      'acknowledged': episode.acknowledged,
      'lastReminderAt': episode.lastReminderAt?.millisecondsSinceEpoch,
      'lastAcceptedStatusAt':
          episode.lastAcceptedStatusAt?.millisecondsSinceEpoch,
      'activeCarbsReq': episode.activeCarbsReq,
      'notificationCancellationPending':
          episode.notificationCancellationPending,
    });
    final saved = await preferences.setString(_episodeKey, encoded);
    if (!saved) {
      throw StateError('Could not persist AAPS carbs request episode.');
    }
  }

  DateTime? _date(Object? milliseconds) {
    return milliseconds is int
        ? DateTime.fromMillisecondsSinceEpoch(milliseconds)
        : null;
  }
}
