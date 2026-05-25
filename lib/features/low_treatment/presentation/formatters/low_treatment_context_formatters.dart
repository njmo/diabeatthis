import '../../../../core/domain/model/low_treatment_context.dart';

String lowTreatmentReasonLabel(LowTreatmentReason reason) {
  return switch (reason) {
    LowTreatmentReason.carbsReq => 'Sugestia AAPS',
    LowTreatmentReason.lowGlucose => 'Niski cukier',
    LowTreatmentReason.fallingTrend => 'Szybki spadek',
    LowTreatmentReason.bgMismatch => 'Błąd sensora',
    LowTreatmentReason.unplannedActivity => 'Aktywność',
    LowTreatmentReason.plannedActivity => 'Aktywność',
    LowTreatmentReason.symptoms => 'Niski cukier',
    LowTreatmentReason.manual => 'Ręcznie',
    LowTreatmentReason.other => 'Inny',
  };
}

String lowTreatmentSourceLabel(LowTreatmentContextSource source) {
  return switch (source) {
    LowTreatmentContextSource.manual => 'Ręcznie',
    LowTreatmentContextSource.aapsSuggestion => 'Sugestia AAPS',
    LowTreatmentContextSource.dashboardAction => 'Dashboard',
  };
}
