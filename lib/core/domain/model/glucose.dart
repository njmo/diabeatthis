import 'package:freezed_annotation/freezed_annotation.dart';

part 'glucose.freezed.dart';

@freezed
abstract class Glucose with _$Glucose{
  const factory Glucose({
    required int id,
    required DateTime date,
    required int sgv,
    required String direction,
    int? tick,
  }) = _Glucose;
}