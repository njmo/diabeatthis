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

@freezed
abstract class Glucose with _$Glucose {
  const factory Glucose({
    required int id,
    required String? externalId,
    required GlucoseSource source,
    required DateTime date,
    required int sgv,
    required String direction,
  }) = _Glucose;

  factory Glucose.fromJson(Map<String, dynamic> json) =>
      _$GlucoseFromJson(json);
}
