import 'package:freezed_annotation/freezed_annotation.dart';

import 'app/app_event.dart';
import 'local_glucose/local_glucose_event.dart';
import 'notification/notification_response_event.dart';

part 'external_event.freezed.dart';
part 'external_event.g.dart';

@Freezed(unionKey: 'external_event', unionValueCase: FreezedUnionCase.snake)
sealed class ExternalEvent with _$ExternalEvent {
  const ExternalEvent._();

  const factory ExternalEvent.appEvent({required AppEvent data}) =
      _ExternalAppEvent;

  const factory ExternalEvent.notificationEvent({
    required NotificationResponseEvent data,
  }) = _ExternalNotificationEvent;

  const factory ExternalEvent.localGlucose({required LocalGlucoseEvent data}) =
      _ExternalLocalGlucoseEvent;

  factory ExternalEvent.fromJson(Map<String, dynamic> json) =>
      _$ExternalEventFromJson(json);
}
