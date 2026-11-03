import '../../../../common/l10n/language.dart';
import '../../../../common/platform/aaps_launcher.dart';
import '../../application/open_low_treatment_aaps_use_case.dart';

class LowTreatmentAapsController {
  const LowTreatmentAapsController(this._open, {this.hasUpload});
  final OpenLowTreatmentAapsUseCase _open;
  final Future<bool> Function(int)? hasUpload;

  Future<bool> usesNightscout(int mealId) async =>
      await hasUpload?.call(mealId) ?? false;

  Future<AapsLaunchResult> open(int mealId, AppLocalizations strings) async {
    // A persisted upload owns this intake, even if the switch is now disabled.
    if (await usesNightscout(mealId)) return AapsLaunchResult.opened;
    return _open(mealId, strings);
  }
}
