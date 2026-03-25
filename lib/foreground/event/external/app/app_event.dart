import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../common/events/data/app/dump_logs_event.dart';
import '../../../../common/events/data/app/execute_command_event.dart';
import '../../../../common/events/data/app/lifecycle_state_event.dart';

part 'app_event.freezed.dart';
part 'app_event.g.dart';

@Freezed(
  unionKey: 'app_event',
  unionValueCase: FreezedUnionCase.snake,
)
sealed class AppEvent with _$AppEvent {
  const AppEvent._();

  const factory AppEvent.appLifecycleState({
    required LifecycleStateEvent data,
  }) = AppLifecycleStateEvent;

  const factory AppEvent.executeCommand({
    required ExecuteCommandEvent data,
  }) = AppExecuteCommandEvent;

  const factory AppEvent.dumpLogs({
    required DumpLogsEvent data,
  }) = _DumpLogsEvent;

  factory AppEvent.fromJson(Map<String, dynamic> json) =>
      _$AppEventFromJson(json);
}