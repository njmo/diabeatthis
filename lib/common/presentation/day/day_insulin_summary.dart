import '../../history/insulin_basal_summary.dart';
import '../../history/insulin_bolus_summary.dart';
import '../../l10n/language.dart';
import '../../utils/format_duration_label.dart';

/// Availability and totals shared by the compact and detailed insulin views.
/// Basal values describe observed intervals only; missing sources stay unknown.
class DayInsulinSummary {
  const DayInsulinSummary({required this.boluses, required this.basal});

  final InsulinBolusSummary? boluses;
  final InsulinBasalSummary? basal;

  double? get basalUnits =>
      basal != null && basal!.coveredDuration > Duration.zero
      ? basal!.units
      : null;

  double? get totalUnits => basalUnits != null && boluses != null
      ? basalUnits! + boluses!.units
      : null;

  bool get isPartial => basal?.coverage != 1;

  List<String> warnings(
    AppLocalizations lang, {
    bool isNight = false,
    bool includeBoluses = true,
  }) {
    final basalTitle = isNight ? lang.dayNightBasalTitle : lang.dayBasalTitle;
    final data = basal;
    return [
      if (includeBoluses && boluses == null)
        '${lang.dayRecordedBoluses}: ${lang.daySourceUnavailable}',
      if (data == null)
        '$basalTitle: ${lang.daySourceUnavailable}'
      else if (data.coveredDuration < data.duration)
        '$basalTitle: ${lang.dayWarningMissingDuration(formatDurationLabel(data.duration - data.coveredDuration))}',
    ];
  }
}
