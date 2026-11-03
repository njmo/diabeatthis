import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/handoff/controllers/handoff_controller.dart';
import '../../../../common/platform/aaps_launcher.dart';
import '../../../../common/platform/external_app_instruction_pip.dart';
import '../../application/confirm_low_treatment_aaps_use_case.dart';
import '../../application/open_low_treatment_aaps_use_case.dart';
import '../../presentation/controllers/low_treatment_aaps_controller.dart';
import 'low_treatment_upload_provider.dart';
import 'recorded_low_treatment_repository_provider.dart';

final lowTreatmentPipControllerProvider = Provider<HandoffController>(
  (ref) => HandoffController(
    ExternalAppInstructionPip(enabled: !kIsWeb && Platform.isAndroid),
  ),
);

final openLowTreatmentAapsUseCaseProvider =
    Provider<OpenLowTreatmentAapsUseCase>(
      (ref) => OpenLowTreatmentAapsUseCase(
        loadRecorded: (mealId) => !kIsWeb && Platform.isAndroid
            ? ref
                  .read(recordedLowTreatmentRepositoryProvider)
                  .fetchByMealId(mealId)
            : Future.value(null),
        handoff: ref.watch(lowTreatmentPipControllerProvider),
        launcher: ref.watch(aapsLauncherProvider),
      ),
    );

final lowTreatmentAapsControllerProvider = Provider<LowTreatmentAapsController>(
  (ref) => LowTreatmentAapsController(
    ref.watch(openLowTreatmentAapsUseCaseProvider),
    hasUpload: (mealId) async =>
        !kIsWeb &&
        Platform.isAndroid &&
        await ref.read(lowTreatmentUploadRepositoryProvider).find(mealId) !=
            null,
  ),
);

final confirmLowTreatmentAapsUseCaseProvider =
    Provider<ConfirmLowTreatmentAapsUseCase>(
      (ref) => ConfirmLowTreatmentAapsUseCase(
        ref.watch(lowTreatmentPipControllerProvider),
      ),
    );
