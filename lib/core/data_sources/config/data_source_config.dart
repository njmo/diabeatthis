enum BgSource {
  cloud('cloud'),
  aaps('aaps'),
  xdrip('xdrip');

  const BgSource(this.storageValue);

  final String storageValue;

  static BgSource fromStorage(String? value) {
    return BgSource.values.firstWhere(
      (source) => source.storageValue == value,
      orElse: () => BgSource.cloud,
    );
  }
}

enum EventSource {
  cloud('cloud'),
  aaps('aaps');

  const EventSource(this.storageValue);

  final String storageValue;

  static EventSource fromStorage(String? value) {
    return EventSource.values.firstWhere(
      (source) => source.storageValue == value,
      orElse: () => EventSource.cloud,
    );
  }
}

enum PumpStatusSource {
  cloud('cloud'),
  aaps('aaps');

  const PumpStatusSource(this.storageValue);

  final String storageValue;

  static PumpStatusSource fromStorage(String? value) {
    return PumpStatusSource.values.firstWhere(
      (source) => source.storageValue == value,
      orElse: () => PumpStatusSource.cloud,
    );
  }
}

enum HistorySource {
  cloud('cloud'),
  local('local');

  const HistorySource(this.storageValue);

  final String storageValue;

  static HistorySource fromStorage(String? value) {
    return HistorySource.values.firstWhere(
      (source) => source.storageValue == value,
      orElse: () => HistorySource.cloud,
    );
  }
}

class DataSourceConfig {
  const DataSourceConfig({
    required this.bgSource,
    required this.eventSource,
    required this.pumpStatusSource,
    required this.historySource,
    required this.mirrorToLocal,
  });

  const DataSourceConfig.defaults()
    : bgSource = BgSource.cloud,
      eventSource = EventSource.cloud,
      pumpStatusSource = PumpStatusSource.cloud,
      historySource = HistorySource.cloud,
      mirrorToLocal = false;

  final BgSource bgSource;
  final EventSource eventSource;
  final PumpStatusSource pumpStatusSource;
  final HistorySource historySource;
  final bool mirrorToLocal;

  DataSourceConfig copyWith({
    BgSource? bgSource,
    EventSource? eventSource,
    PumpStatusSource? pumpStatusSource,
    HistorySource? historySource,
    bool? mirrorToLocal,
  }) {
    return DataSourceConfig(
      bgSource: bgSource ?? this.bgSource,
      eventSource: eventSource ?? this.eventSource,
      pumpStatusSource: pumpStatusSource ?? this.pumpStatusSource,
      historySource: historySource ?? this.historySource,
      mirrorToLocal: mirrorToLocal ?? this.mirrorToLocal,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DataSourceConfig &&
            bgSource == other.bgSource &&
            eventSource == other.eventSource &&
            pumpStatusSource == other.pumpStatusSource &&
            historySource == other.historySource &&
            mirrorToLocal == other.mirrorToLocal;
  }

  @override
  int get hashCode {
    return Object.hash(
      bgSource,
      eventSource,
      pumpStatusSource,
      historySource,
      mirrorToLocal,
    );
  }
}
