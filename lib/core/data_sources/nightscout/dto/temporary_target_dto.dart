import 'package:freezed_annotation/freezed_annotation.dart';

// ignore_for_file: invalid_annotation_target
part 'temporary_target_dto.freezed.dart';
part 'temporary_target_dto.g.dart';

@freezed
abstract class TemporaryTargetDto with _$TemporaryTargetDto {
  const factory TemporaryTargetDto({
    @JsonKey(name: 'created_at') required String createdAt,
    @JsonKey(name: '_id') required String? nightscoutId,
    required int durationInMilliseconds,
    required int duration,
    required int targetBottom,
    required int targetTop,
    @Default(true) bool isValid,
  }) = _TemporaryTargetDto;

  factory TemporaryTargetDto.fromJson(Map<String, dynamic> json) =>
      TemporaryTargetDto(
        createdAt: json['created_at'] as String,
        nightscoutId: switch (json['_id']) {
          final String id when id.isNotEmpty => id,
          _ => null,
        },
        durationInMilliseconds:
            (json['durationInMilliseconds'] as num?)?.toInt() ??
            Duration(minutes: (json['duration'] as num).toInt()).inMilliseconds,
        duration: (json['duration'] as num).toInt(),
        targetBottom: (json['targetBottom'] as num?)?.toInt() ?? 0,
        targetTop: (json['targetTop'] as num?)?.toInt() ?? 0,
        isValid: (json['isValid'] as bool?) ?? true,
      );
}
