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

  bool get isPushBased {
    return switch (this) {
      BgSource.cloud => false,
      BgSource.aaps || BgSource.xdrip => true,
    };
  }
}

enum TreatmentsSource {
  cloud('cloud'),
  aaps('aaps');

  const TreatmentsSource(this.storageValue);

  final String storageValue;

  static TreatmentsSource fromStorage(String? value) {
    return TreatmentsSource.values.firstWhere(
      (source) => source.storageValue == value,
      orElse: () => TreatmentsSource.cloud,
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

  bool get isPushBased {
    return switch (this) {
      PumpStatusSource.cloud => false,
      PumpStatusSource.aaps => true,
    };
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
    required this.treatmentsSource,
    required this.pumpStatusSource,
    required this.historySource,
    required this.mirrorToLocal,
  });

  const DataSourceConfig.defaults()
    : bgSource = BgSource.cloud,
      treatmentsSource = TreatmentsSource.cloud,
      pumpStatusSource = PumpStatusSource.cloud,
      historySource = HistorySource.cloud,
      mirrorToLocal = false;

  final BgSource bgSource;
  final TreatmentsSource treatmentsSource;
  final PumpStatusSource pumpStatusSource;
  final HistorySource historySource;
  final bool mirrorToLocal;

  bool get usesCloud {
    return bgSource == BgSource.cloud ||
        treatmentsSource == TreatmentsSource.cloud ||
        pumpStatusSource == PumpStatusSource.cloud ||
        historySource == HistorySource.cloud;
  }

  DataSourceConfig copyWith({
    BgSource? bgSource,
    TreatmentsSource? treatmentsSource,
    PumpStatusSource? pumpStatusSource,
    HistorySource? historySource,
    bool? mirrorToLocal,
  }) {
    return DataSourceConfig(
      bgSource: bgSource ?? this.bgSource,
      treatmentsSource: treatmentsSource ?? this.treatmentsSource,
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
            treatmentsSource == other.treatmentsSource &&
            pumpStatusSource == other.pumpStatusSource &&
            historySource == other.historySource &&
            mirrorToLocal == other.mirrorToLocal;
  }

  @override
  int get hashCode {
    return Object.hash(
      bgSource,
      treatmentsSource,
      pumpStatusSource,
      historySource,
      mirrorToLocal,
    );
  }
}
