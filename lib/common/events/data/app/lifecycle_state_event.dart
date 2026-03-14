import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../foreground/event/model/foreground_event.dart';
import '../app_event_data.dart';

part 'lifecycle_state_event.freezed.dart';
part 'lifecycle_state_event.g.dart';

@Freezed(unionKey: 'type', unionValueCase: FreezedUnionCase.snake)
abstract class LifecycleStateEvent
    with _$LifecycleStateEvent, AppEventData implements ForegroundEvent {
  const LifecycleStateEvent._();

  const factory LifecycleStateEvent.changed({
    required int state,
  }) = LifecycleStateEventChanged;

  factory LifecycleStateEvent.fromJson(Map<String, dynamic> json) =>
      _$LifecycleStateEventFromJson(json);

  @override
  String get eventName => 'app_lifecycle_state';
}