import 'package:freezed_annotation/freezed_annotation.dart';

import '../../app_event_payload.dart';

part 'app_lifecycle_payload.freezed.dart';
part 'app_lifecycle_payload.g.dart';

@freezed
abstract class AppLifecyclePayload
    with _$AppLifecyclePayload, AppEventPayload {
  const AppLifecyclePayload._();

  const factory AppLifecyclePayload({
    required int state,
  }) = _AppLifecyclePayload;

  factory AppLifecyclePayload.fromJson(Map<String, dynamic> json) =>
      _$AppLifecyclePayloadFromJson(json);

  @override
  String get eventName => 'app_lifecycle_change';
}