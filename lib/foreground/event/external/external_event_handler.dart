import 'dart:async';

import '../../../core/logger/logger.dart';
import '../../task/base/runtime_context.dart';
import 'app/app_event_handler.dart';
import 'external_event.dart';
import 'local_device_status/local_device_status_handler.dart';
import 'local_glucose/local_glucose_handler.dart';
import 'notification/notification_response_event_handler.dart';

class ExternalEventHandler with Logging {
  final RuntimeContext _runtimeContext;
  final AppEventHandler _appEventHandler;
  final LocalDeviceStatusHandler _localDeviceStatusHandler;
  final LocalGlucoseHandler _localGlucoseHandler;
  final NotificationResponseEventHandler _notificationResponseEventHandler;

  ExternalEventHandler(this._runtimeContext)
    : _appEventHandler = AppEventHandler(),
      _localDeviceStatusHandler = LocalDeviceStatusHandler(),
      _localGlucoseHandler = LocalGlucoseHandler(),
      _notificationResponseEventHandler = NotificationResponseEventHandler();

  void handle(Map<String, dynamic> event) {
    final externalEvent = ExternalEvent.fromJson(event);

    externalEvent.when(
      appEvent: (data) => _appEventHandler.handle(data, _runtimeContext),
      localGlucose: (data) => unawaited(
        _localGlucoseHandler.handle(data, _runtimeContext).catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          logE(
            'Local glucose event handling failed',
            error: error,
            stackTrace: stackTrace,
          );
        }),
      ),
      localDeviceStatus: (data) => unawaited(
        _localDeviceStatusHandler.handle(data, _runtimeContext).catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          logE(
            'Local device status event handling failed',
            error: error,
            stackTrace: stackTrace,
          );
        }),
      ),
      notificationEvent: (data) =>
          _notificationResponseEventHandler.handle(data, _runtimeContext),
    );
  }
}
