import 'package:freezed_annotation/freezed_annotation.dart';

part 'portion.freezed.dart';
part 'portion.g.dart';

@freezed
abstract class Portion with _$Portion {
  const factory Portion({
    required int id,
    required String name,
    required String unitHint,
  }) = _Portion;

  factory Portion.fromJson(Map<String, dynamic> json) =>
      _$PortionFromJson(json);
}
