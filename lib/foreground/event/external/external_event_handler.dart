import '../../../common/treatments/native_treatment_payloads.dart';
import '../../../common/treatments/raw_treatment_batch_buffer.dart';
import '../../../core/logger/logger.dart';
import '../../task/base/runtime_context.dart';
import 'app/app_event_handler.dart';
import 'external_event.dart';
import 'local_treatments/local_treatments_event.dart';
import 'native_receiver/native_receiver_event_handler.dart';
import 'notification/notification_response_event_handler.dart';

class ExternalEventHandler with Logging {
  final RuntimeContext _runtimeContext;
  late final RawTreatmentBatchBuffer _treatmentBuffer = RawTreatmentBatchBuffer(
    onBatch: (records) => _nativeReceiverEventHandler.handleTreatments(
      LocalTreatmentsEvent.fromRawPayloads(records),
      _runtimeContext,
    ),
    onPendingWizards: (records) => _nativeReceiverEventHandler.handleTreatments(
      LocalTreatmentsEvent.fromRawPayloads(records),
      _runtimeContext,
    ),
    onError: (error, stackTrace) => logE(
      'Buffered native treatments handling failed',
      error: error,
      stackTrace: stackTrace,
    ),
  );
  final AppEventHandler _appEventHandler;
  final NativeReceiverEventHandler _nativeReceiverEventHandler;
  final NotificationResponseEventHandler _notificationResponseEventHandler;

  ExternalEventHandler(this._runtimeContext)
    : _appEventHandler = AppEventHandler(),
      _nativeReceiverEventHandler = NativeReceiverEventHandler(),
      _notificationResponseEventHandler = NotificationResponseEventHandler();

  Future<void> flushPendingTreatments() => _treatmentBuffer.flush();

  void handle(Map<String, dynamic> event) {
    final rawTreatments = nativeTreatmentPayloads(event);
    if (rawTreatments != null) {
      _treatmentBuffer.add(rawTreatments);
      return;
    }
    final externalEvent = ExternalEvent.fromJson(event);

    externalEvent.when(
      appEvent: (data) => _appEventHandler.handle(data, _runtimeContext),
      nativeReceiver: (data) =>
          _nativeReceiverEventHandler.handle(data, _runtimeContext),
      notificationEvent: (data) =>
          _notificationResponseEventHandler.handle(data, _runtimeContext),
    );
  }
}
