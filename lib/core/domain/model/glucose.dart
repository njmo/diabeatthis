import 'package:freezed_annotation/freezed_annotation.dart';

part 'glucose.freezed.dart';
part 'glucose.g.dart';

@JsonEnum(valueField: 'storageValue')
enum GlucoseSource {
  cloud('cloud'),
  aaps('aaps'),
  xdrip('xdrip');

  const GlucoseSource(this.storageValue);

  final String storageValue;

  static GlucoseSource fromStorage(String? value) {
    return GlucoseSource.values.firstWhere(
      (source) => source.storageValue == value,
      orElse: () => GlucoseSource.cloud,
    );
  }
}

/// CGM samples form the glucose time series; the other types are spot checks.
enum GlucoseType { cgm, finger, sensor, manual, other }

@freezed
abstract class Glucose with _$Glucose {
  const factory Glucose({
    required String? externalId,
    required GlucoseSource source,
    required DateTime date,
    required int sgv,
    required String direction,
    @Default(GlucoseType.cgm) GlucoseType type,
    String? notes,
  }) = _Glucose;

  factory Glucose.fromJson(Map<String, dynamic> json) =>
      _$GlucoseFromJson(json);
}
