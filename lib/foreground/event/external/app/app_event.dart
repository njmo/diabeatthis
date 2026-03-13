import 'package:freezed_annotation/freezed_annotation.dart';

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

  factory AppEvent.fromJson(Map<String, dynamic> json) =>
      _$AppEventFromJson(json);
}