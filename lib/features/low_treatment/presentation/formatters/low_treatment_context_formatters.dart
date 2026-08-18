import '../../../../common/l10n/language.dart';
import '../../../../core/domain/model/low_treatment_context.dart';

String lowTreatmentReasonLabel(
  LowTreatmentReason reason, [
  AppLocalizations? localizations,
]) {
  final lang = localizations ?? LanguageStrings.current;
  return switch (reason) {
    LowTreatmentReason.carbsReq => lang.lowTreatmentReasonCarbsReq,
    LowTreatmentReason.lowGlucose => lang.lowTreatmentReasonLowGlucose,
    LowTreatmentReason.fallingTrend => lang.lowTreatmentReasonFallingTrend,
    LowTreatmentReason.bgMismatch => lang.lowTreatmentReasonBgMismatch,
    LowTreatmentReason.unplannedActivity => lang.lowTreatmentReasonActivity,
    LowTreatmentReason.plannedActivity => lang.lowTreatmentReasonActivity,
    LowTreatmentReason.symptoms => lang.lowTreatmentReasonLowGlucose,
    LowTreatmentReason.manual => lang.lowTreatmentReasonManual,
    LowTreatmentReason.other => lang.lowTreatmentReasonOther,
  };
}

String lowTreatmentSourceLabel(
  LowTreatmentContextSource source, [
  AppLocalizations? localizations,
]) {
  final lang = localizations ?? LanguageStrings.current;
  return switch (source) {
    LowTreatmentContextSource.manual => lang.lowTreatmentReasonManual,
    LowTreatmentContextSource.aapsSuggestion => lang.lowTreatmentReasonCarbsReq,
    LowTreatmentContextSource.dashboardAction => 'Dashboard',
  };
}
