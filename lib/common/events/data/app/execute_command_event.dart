import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../foreground/event/model/foreground_event.dart';
import '../app_event_data.dart';

part 'execute_command_event.freezed.dart';
part 'execute_command_event.g.dart';

@Freezed(unionKey: 'command', unionValueCase: FreezedUnionCase.snake)
abstract class ExecuteCommandEvent
    with _$ExecuteCommandEvent, AppEventData implements ForegroundEvent {
  const ExecuteCommandEvent._();

  const factory ExecuteCommandEvent.syncData({
    required List<String> data,
  }) = ExecuteCommandEventSyncData;

  factory ExecuteCommandEvent.fromJson(Map<String, dynamic> json) =>
      _$ExecuteCommandEventFromJson(json);

  @override
  String get eventName => 'execute_command';
}