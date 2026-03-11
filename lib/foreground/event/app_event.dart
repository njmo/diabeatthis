import 'package:freezed_annotation/freezed_annotation.dart';

import '../../common/task_events/app_event_payload.dart';
import '../../common/task_events/payloads/app_lifecycle_payload.dart';

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

  factory AppEvent.fromPayload(AppEventPayload payload) {
    return switch (payload) {
      final AppLifecyclePayload p => AppEvent.appLifecycleChange(data: p),
      _ => throw UnsupportedError(
        'Unsupported payloads type: ${payload.runtimeType}',
      ),
    };
  }
}