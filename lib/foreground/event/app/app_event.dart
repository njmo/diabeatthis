import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../common/events/app_event_payload.dart';
import '../../../common/events/payloads/app/app_lifecycle_payload.dart';

part 'app_event.freezed.dart';
part 'app_event.g.dart';

@Freezed(
  unionKey: 'event',
  unionValueCase: FreezedUnionCase.snake,
)
sealed class AppEvent with _$AppEvent {
  const AppEvent._();

  const factory AppEvent.appLifecycleChange({
    required AppLifecyclePayload data,
  }) = AppLifecycleChangeEvent;

  factory AppEvent.fromJson(Map<String, dynamic> json) =>
      _$AppEventFromJson(json);
}