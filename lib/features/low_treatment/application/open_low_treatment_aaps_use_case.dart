import 'package:intl/intl.dart';

import '../../../common/handoff/controllers/handoff_controller.dart';
import '../../../common/handoff/handoff_instruction.dart';
import '../../../common/handoff/handoff_step.dart';
import '../../../common/l10n/language.dart';
import '../../../common/platform/aaps_launcher.dart';
import '../../../common/platform/external_app_installation_checker.dart';
import '../domain/models/low_treatment_pip_session.dart';
import '../domain/models/recorded_low_treatment.dart';

class OpenLowTreatmentAapsUseCase {
  const OpenLowTreatmentAapsUseCase({
    required this.loadRecorded,
    required this.handoff,
    required this.launcher,
  });

  final Future<RecordedLowTreatment?> Function(int) loadRecorded;
  final HandoffController handoff;
  final AapsLauncher launcher;

  Future<AapsLaunchResult> call(int mealId, AppLocalizations strings) async {
    // The persisted consumption, rather than the AAPS suggestion, is authoritative.
    final recorded = await loadRecorded(mealId);
    final carbs = recorded?.netCarbsGrams;
    if (carbs != null && carbs.isFinite && carbs > 0) {
      final opened = await handoff.open(
        instruction: HandoffInstruction(
          title: strings.lowTreatmentRecordTitle,
          closeLabel: strings.aapsSuggestionClose,
          steps: [
            HandoffStep(
              label: strings.aapsPipCarbs,
              value:
                  '${NumberFormat('0.###', strings.localeName).format(carbs)} g',
              actionId: LowTreatmentPipSession.carbsAction,
            ),
          ],
        ),
        packageName: ExternalDataApp.aaps.androidPackageName,
        sessionId: LowTreatmentPipSession.forMeal(mealId),
      );
      if (opened) return AapsLaunchResult.opened;
    }
    return launcher.openAaps();
  }
}
