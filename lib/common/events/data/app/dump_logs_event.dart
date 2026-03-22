import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../foreground/event/model/foreground_event.dart';
import '../app_event_data.dart';

part 'dump_logs_event.freezed.dart';
part 'dump_logs_event.g.dart';

@Freezed(unionKey: 'type', unionValueCase: FreezedUnionCase.snake)
abstract class DumpLogsEvent
    with _$DumpLogsEvent, AppEventData implements ForegroundEvent {
  const DumpLogsEvent._();

  const factory DumpLogsEvent.saveToFile({
    required String name,
  }) = _DumpLogsEvent;

  factory DumpLogsEvent.fromJson(Map<String, dynamic> json) =>
      _$DumpLogsEventFromJson(json);

  @override
  String get eventName => 'dump_logs';
}