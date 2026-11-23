import '../../../../core/data_sources/config/data_source_config.dart';
import '../../../../core/data_sources/config/data_source_config_provider.dart';
import '../../../../core/data_sources/local_mirror/providers/local_mirror_writer_provider.dart';
import '../../../../core/domain/model/manual_bolus.dart';
import '../../../../core/domain/model/treat.dart';
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

    Log.diagnostic(
      'AapsTreatmentTrace',
      'parsed=${event.data.length} '
          'raw=${event.rawPayloads.length} source=${config.treatmentsSource.storageValue} '
          'mirror=${config.mirrorToLocal}',
    );
    if (config.treatmentsSource != TreatmentsSource.aaps) {
      Log.diagnostic(
        'AapsTreatmentTrace',
        'aapsBatchIgnored configuredSource=${config.treatmentsSource.storageValue}',
      );
      logI(
        'Ignoring local treatments from AAPS; configured treatments source is '
        '${config.treatmentsSource.storageValue}',
      );
      return;
    }

    var treatments = event.data;
    if (config.mirrorToLocal) {
      treatments = await container
          .read(localMirrorWriterProvider)
          .mirrorTreatments(event.data, TreatmentsSource.aaps);
    } else {
      for (final treatment in treatments) {
        final type = switch (treatment) {
          ManualBolus() => 'ManualBolus',
          Treat() => 'Treat',
          _ => null,
        };
        if (type == null) continue;
        Log.diagnostic(
          'AapsTreatmentTrace',
          'mirror type=$type at=${treatment.createdAt?.millisecondsSinceEpoch} '
              'source=aaps decision=disabled',
        );
      }
    }

    Log.diagnostic('AapsTreatmentTrace', 'dispatching=${treatments.length}');
    _treatmentEventDispatcher.dispatchBatch(
      container: container,
      emitEvent: runtimeContext.emitEvent,
      treatments: treatments,
    );
  }
}
