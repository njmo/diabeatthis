class AapsCarbsRequestEpisode {
  final String? id;
  final bool acknowledged;
  final DateTime? lastReminderAt;
  final DateTime? lastAcceptedStatusAt;
  final double? activeCarbsReq;
  final bool notificationCancellationPending;

  const AapsCarbsRequestEpisode({
    required this.id,
    required this.acknowledged,
    required this.lastReminderAt,
    required this.lastAcceptedStatusAt,
    required this.activeCarbsReq,
    required this.notificationCancellationPending,
  });

  const AapsCarbsRequestEpisode.empty()
    : id = null,
      acknowledged = false,
      lastReminderAt = null,
      lastAcceptedStatusAt = null,
      activeCarbsReq = null,
      notificationCancellationPending = false;

  bool matchesSuggestionAt(DateTime? suggestionAt) {
    final episodeId = id;
    final latest = lastAcceptedStatusAt;
    if (suggestionAt == null || episodeId == null || latest == null) {
      return false;
    }
    final separator = episodeId.indexOf(':');
    final micros = int.tryParse(
      separator < 0 ? episodeId : episodeId.substring(0, separator),
    );
    if (micros == null) return false;
    final start = DateTime.fromMicrosecondsSinceEpoch(micros);
    return !suggestionAt.isBefore(start) && !suggestionAt.isAfter(latest);
  }

  AapsCarbsRequestEpisode start(String episodeId) {
    return AapsCarbsRequestEpisode(
      id: episodeId,
      acknowledged: false,
      lastReminderAt: null,
      lastAcceptedStatusAt: lastAcceptedStatusAt,
      activeCarbsReq: activeCarbsReq,
      notificationCancellationPending: notificationCancellationPending,
    );
  }

  AapsCarbsRequestEpisode reminded(DateTime at) {
    return AapsCarbsRequestEpisode(
      id: id,
      acknowledged: acknowledged,
      lastReminderAt: at,
      lastAcceptedStatusAt: lastAcceptedStatusAt,
      activeCarbsReq: activeCarbsReq,
      notificationCancellationPending: notificationCancellationPending,
    );
  }

  AapsCarbsRequestEpisode acceptStatus(DateTime at, double? activeCarbsReq) {
    return AapsCarbsRequestEpisode(
      id: id,
      acknowledged: acknowledged,
      lastReminderAt: lastReminderAt,
      lastAcceptedStatusAt: at,
      activeCarbsReq: activeCarbsReq,
      notificationCancellationPending: notificationCancellationPending,
    );
  }

  AapsCarbsRequestEpisode acknowledge(String episodeId) {
    if (id != episodeId) return this;
    return AapsCarbsRequestEpisode(
      id: id,
      acknowledged: true,
      lastReminderAt: lastReminderAt,
      lastAcceptedStatusAt: lastAcceptedStatusAt,
      activeCarbsReq: activeCarbsReq,
      notificationCancellationPending: true,
    );
  }

  AapsCarbsRequestEpisode clear() {
    return AapsCarbsRequestEpisode(
      id: null,
      acknowledged: false,
      lastReminderAt: null,
      lastAcceptedStatusAt: lastAcceptedStatusAt,
      activeCarbsReq: null,
      notificationCancellationPending: true,
    );
  }

  AapsCarbsRequestEpisode cancelled() {
    return AapsCarbsRequestEpisode(
      id: id,
      acknowledged: acknowledged,
      lastReminderAt: lastReminderAt,
      lastAcceptedStatusAt: lastAcceptedStatusAt,
      activeCarbsReq: activeCarbsReq,
      notificationCancellationPending: false,
    );
  }
}
