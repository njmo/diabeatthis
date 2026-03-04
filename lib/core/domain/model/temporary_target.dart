import 'package:freezed_annotation/freezed_annotation.dart';

part 'temporary_target.freezed.dart';

@Freezed(unionKey: 'kind')
abstract class TemporaryTarget with _$TemporaryTarget {
  const factory TemporaryTarget({
    required DateTime createdAt,
    required int durationInMiliseconds,
    required int duration,
    required int targetBottom,
    required int targetTop,
  }) = _TemporaryTarget;
}
