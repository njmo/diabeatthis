import 'dart:async';

import '../../../../core/logger/logger.dart';
import '../../../task/base/runtime_context.dart';
import '../local_device_status/local_device_status_handler.dart';
import '../local_glucose/local_glucose_handler.dart';
import '../local_treatments/local_treatments_handler.dart';
import 'native_receiver_event.dart';

class NativeReceiverEventHandler with Logging {
  final _localDeviceStatusHandler = LocalDeviceStatusHandler();
  final _localGlucoseHandler = LocalGlucoseHandler();
  final _localTreatmentsHandler = LocalTreatmentsHandler();

  void handle(NativeReceiverEvent event, RuntimeContext runtimeContext) {
    event.when(
      glucose: (data) => unawaited(
        _localGlucoseHandler.handle(data, runtimeContext).catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          logE(
            'Native glucose receiver event handling failed',
            error: error,
            stackTrace: stackTrace,
          );
        }),
      ),
      deviceStatus: (data) => unawaited(
        _localDeviceStatusHandler.handle(data, runtimeContext).catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          logE(
            'Native device status receiver event handling failed',
            error: error,
            stackTrace: stackTrace,
          );
        }),
      ),
      treatments: (data) => unawaited(
        _localTreatmentsHandler.handle(data, runtimeContext).catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          logE(
            'Native treatments receiver event handling failed',
            error: error,
            stackTrace: stackTrace,
          );
        }),
      ),
    );
  }
}
