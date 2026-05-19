import 'package:freezed_annotation/freezed_annotation.dart';

part 'activity.freezed.dart';

const defaultPlannedActivityDurationMinutes = 30;

@freezed
abstract class Activity with _$Activity {
  const factory Activity({
    required int id,
    required String name,
    required int percentagePre,
    required int percentagePost,
    required int? durationMinutes,
  }) = _Activity;
}
