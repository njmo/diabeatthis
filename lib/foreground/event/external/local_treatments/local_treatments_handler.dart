import '../../../../core/data_sources/config/data_source_config.dart';
import '../../../../core/data_sources/config/data_source_config_provider.dart';
import '../../../../core/data_sources/local_mirror/providers/local_mirror_writer_provider.dart';
import '../../../../core/logger/logger.dart';
import '../../../event/internal/treatment_event_dispatcher.dart';
import '../../../task/base/runtime_context.dart';
import 'local_treatments_event.dart';

class LocalTreatmentsHandler with Logging {
  final _treatmentEventDispatcher = TreatmentEventDispatcher();

  Future<void> handle(
    LocalTreatmentsEvent event,
    RuntimeContext runtimeContext,
  ) async {
    final container = runtimeContext.container;
    final config = await container.read(dataSourceConfigProvider.future);

    if (config.treatmentsSource != TreatmentsSource.aaps) {
      logI(
        'Ignoring local treatments from AAPS; configured treatments source is '
        '${config.treatmentsSource.storageValue}',
      );
      return;
    }

    if (config.mirrorToLocal) {
      await container
          .read(localMirrorWriterProvider)
          .mirrorTreatments(event.data, TreatmentsSource.aaps);
    }

    for (final treatment in event.data) {
      _treatmentEventDispatcher.dispatch(
        container: container,
        emitEvent: runtimeContext.emitEvent,
        treatment: treatment,
      );
    }
  }
}
