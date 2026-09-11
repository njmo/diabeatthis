import 'dart:convert';

enum DaySummaryMetric {
  totalInsulinUnits,
  glucoseMean,
  glucoseLowPercent,
  glucoseInRangePercent,
  glucoseHighPercent,
  glucoseMax,
  glucoseCoveragePercent,
  nightGlucoseMean,
  nightInRangePercent,
  nightGlucoseCoveragePercent,
  basalUnits,
  basalAddedUnits,
  basalReducedUnits,
  basalCoveragePercent,
  bolusUnits,
  smbUnits,
  smbCount,
  nightBasalUnits,
  nightBasalCoveragePercent,
  nightBolusUnits,
  nightSmbUnits,
  nightSmbCount,
  mealCount,
  netCarbsGrams,
  proteinGrams,
  fatGrams,
  lowTreatmentCount,
  lowTreatmentCarbsGrams,
  activityMinutes,
  sensorAgeMinutes,
  podAgeMinutes,
}

/// Aggregate facts only. No copied CGM, device-status or treatment history.
class DaySummarySnapshot {
  static const schemaVersion = 1;
  final String dayKey;
  final DateTime asOf;
  final DateTime builtAt;
  final DateTime? nightStart;
  final DateTime? nightEnd;
  final int utcOffsetMinutes;
  final Map<String, int> displayUtcOffsets;
  final Map<DaySummaryMetric, num?> metrics;
  final List<String> limitations;
  final List<DaySummaryReviewRecord> review;

  DaySummarySnapshot({
    this.nightStart,
    this.nightEnd,
    required this.dayKey,
    required this.asOf,
    required this.builtAt,
    required this.utcOffsetMinutes,
    Map<String, int>? displayUtcOffsets,
    required Map<DaySummaryMetric, num?> metrics,
    required List<String> limitations,
    required List<DaySummaryReviewRecord> review,
  }) : displayUtcOffsets = Map.unmodifiable(
         displayUtcOffsets ??
             {
               for (final instant in [
                 asOf,
                 if (nightStart != null) nightStart,
                 if (nightEnd != null) nightEnd,
                 ...review.map((entry) => entry.occurredAt),
               ])
                 instant.toUtc().toIso8601String(): instant.isUtc
                     ? utcOffsetMinutes
                     : instant.timeZoneOffset.inMinutes,
             },
       ),
       metrics = Map.unmodifiable(metrics),
       limitations = List.unmodifiable(limitations),
       review = List.unmodifiable(review);

  /// A UTC-tagged wall-clock value for formatting; never convert it toLocal().
  DateTime displayTime(DateTime instant) => instant.toUtc().add(
    Duration(
      minutes:
          displayUtcOffsets[instant.toUtc().toIso8601String()] ??
          utcOffsetMinutes,
    ),
  );

  String encode() => jsonEncode(toJson());

  Map<String, dynamic> toJson() => {
    'version': schemaVersion,
    'day': dayKey,
    'asOf': asOf.toUtc().toIso8601String(),
    'nightStart': nightStart?.toUtc().toIso8601String(),
    'nightEnd': nightEnd?.toUtc().toIso8601String(),
    'builtAt': builtAt.toUtc().toIso8601String(),
    'utcOffsetMinutes': utcOffsetMinutes,
    'displayUtcOffsets': displayUtcOffsets,
    'metrics': {
      for (final entry in metrics.entries) entry.key.name: entry.value,
    },
    'limitations': limitations,
    'review': review.map((record) => record.toJson()).toList(),
  };

  factory DaySummarySnapshot.decode(String payload) {
    return DaySummarySnapshot.fromJson(
      jsonDecode(payload) as Map<String, dynamic>,
    );
  }

  factory DaySummarySnapshot.fromJson(Map<String, dynamic> json) {
    if (json['version'] != schemaVersion) {
      throw const FormatException('Unsupported day summary version');
    }
    return DaySummarySnapshot(
      dayKey: json['day'] as String,
      nightStart: json['nightStart'] == null
          ? null
          : DateTime.parse(json['nightStart'] as String),
      nightEnd: json['nightEnd'] == null
          ? null
          : DateTime.parse(json['nightEnd'] as String),
      asOf: DateTime.parse(json['asOf'] as String),
      builtAt: DateTime.parse(json['builtAt'] as String),
      utcOffsetMinutes: json['utcOffsetMinutes'] as int,
      displayUtcOffsets: (json['displayUtcOffsets'] as Map<String, dynamic>?)
          ?.map((key, value) => MapEntry(key, value as int)),
      metrics: (json['metrics'] as Map<String, dynamic>).map(
        (key, value) =>
            MapEntry(DaySummaryMetric.values.byName(key), value as num?),
      ),
      limitations: (json['limitations'] as List).cast<String>(),
      review: (json['review'] as List)
          .map(
            (value) =>
                DaySummaryReviewRecord.fromJson(value as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

enum DaySummaryReviewKind { meal, lowTreatment }

enum DaySummaryResolution { linked, dismissed, unresolved }

class DaySummaryReviewRecord {
  final DaySummaryReviewKind kind;
  final DateTime occurredAt;
  final int? mealId;
  final String? sourceId;
  final DaySummaryResolution resolution;

  const DaySummaryReviewRecord({
    required this.kind,
    required this.occurredAt,
    required this.mealId,
    required this.sourceId,
    required this.resolution,
  });

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'mealId': mealId,
    'sourceId': sourceId,
    'resolution': resolution.name,
  };

  factory DaySummaryReviewRecord.fromJson(Map<String, dynamic> json) =>
      DaySummaryReviewRecord(
        kind: DaySummaryReviewKind.values.byName(json['kind'] as String),
        occurredAt: DateTime.parse(json['occurredAt'] as String),
        mealId: json['mealId'] as int?,
        sourceId: json['sourceId'] as String?,
        resolution: DaySummaryResolution.values.byName(
          json['resolution'] as String,
        ),
      );
}

String daySummaryKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
