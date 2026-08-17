import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_lifecycle_state_provider.dart';
import '../../../common/events/data/task/task_data_synchronization_payload.dart';
import '../../../core/domain/model/bolus_wizard.dart';
import '../../../core/domain/model/correction_bolus.dart';
import '../../../core/domain/model/extended_carb.dart';
import '../../../core/domain/model/manual_bolus.dart';
import '../../../core/domain/model/temporary_target.dart';
import '../../../core/domain/model/treat.dart';
import '../../../core/domain/model/treatment_base.dart';
import '../../../core/logger/logger.dart';
import '../../providers/latest_bolus_wizard_provider.dart';
import '../../providers/task_event_router_provider.dart';
import '../../synchronization/synchronization_cache_controller.dart';
import '../model/foreground_event.dart';
import 'treatment_available_event.dart';

typedef ForegroundEventEmitter = void Function(ForegroundEvent event);

class TreatmentEventDispatcher with Logging {
  void dispatch({
    required ProviderContainer container,
    required ForegroundEventEmitter emitEvent,
    required Treatment treatment,
  }) {
    logI(
      "${treatment.runtimeType} treatment available at "
      "${treatment.createdAt?.toIso8601String()}",
    );

    switch (treatment) {
      case BolusWizard():
        container.read(latestBolusWizardProvider.notifier).update(treatment);
        emitEvent(TreatmentAvailableEvent<BolusWizard>(treatment));
        break;
      case CorrectionBolus():
        emitEvent(TreatmentAvailableEvent<CorrectionBolus>(treatment));
        break;
      case Treat():
        emitEvent(TreatmentAvailableEvent<Treat>(treatment));
        break;
      case ExtendedCarb():
        emitEvent(TreatmentAvailableEvent<ExtendedCarb>(treatment));
        break;
      case ManualBolus():
        emitEvent(TreatmentAvailableEvent<ManualBolus>(treatment));
        break;
      case TemporaryTarget():
        emitEvent(TreatmentAvailableEvent<TemporaryTarget>(treatment));
        _syncTemporaryTarget(container, treatment);
        break;
      default:
        logI("Unknown treatment");
    }
  }

  void _syncTemporaryTarget(
    ProviderContainer container,
    TemporaryTarget target,
  ) {
    final cache = container.read(synchronizationCacheControllerProvider);
    cache.cacheTarget(target);

    if (container.read(appLifecycleProvider) != AppLifecycleState.resumed) {
      return;
    }

    final payload = TaskTargetSynchronization(data: target);
    container.read(taskEventRouterProvider).send(payload);
  }
}
