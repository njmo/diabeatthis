import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../foreground/event/model/foreground_event.dart';
import '../notification_event_data.dart';

part 'temp_target_response_event.freezed.dart';
part 'temp_target_response_event.g.dart';

@Freezed(unionKey: 'action', unionValueCase: FreezedUnionCase.snake)
sealed class TempTargetResponseEvent
    with _$TempTargetResponseEvent, NotificationEventData implements ForegroundEvent {
  const TempTargetResponseEvent._();

  const factory TempTargetResponseEvent.agree({
    required String tempTargetString,
  }) = _TempTargetResponseAgreeEvent;

  const factory TempTargetResponseEvent.empty({
    required int mealId,
  }) = _TempTargetResponseEmptyEvent;

  factory TempTargetResponseEvent.fromJson(Map<String, dynamic> json) =>
      _$TempTargetResponseEventFromJson(json);

  @override
  String get eventName => 'temp_target_response';
}
