import '../common/events/data/app_event_data.dart';

enum DebugTreatmentKind {
  manualBolus('Manual bolus'),
  correctionBolus('Correction bolus'),
  calculator('Calculator'),
  carbs('Carbs'),
  extendedCarbs('Extended carbs');

  const DebugTreatmentKind(this.label);
  final String label;

  bool get hasInsulin =>
      this == manualBolus || this == correctionBolus || this == calculator;

  bool get hasCarbs =>
      this == calculator || this == carbs || this == extendedCarbs;
}

class DebugTreatmentEvent with AppEventData {
  const DebugTreatmentEvent({
    required this.kind,
    this.insulin,
    this.carbs,
    this.minutes,
  });

  static const type = 'debug_treatment';

  final DebugTreatmentKind kind;
  final double? insulin;
  final int? carbs;
  final int? minutes;

  static DebugTreatmentEvent? tryParse(
    DebugTreatmentKind kind, {
    String? insulin,
    String? carbs,
    String? minutes,
  }) {
    final dose = double.tryParse(insulin?.trim().replaceAll(',', '.') ?? '');
    final grams = int.tryParse(carbs?.trim() ?? '');
    final duration = int.tryParse(minutes?.trim() ?? '');
    if (kind.hasInsulin &&
        (dose == null ||
            !dose.isFinite ||
            dose < 0 ||
            (dose == 0 && kind != DebugTreatmentKind.calculator))) {
      return null;
    }
    if (kind.hasCarbs &&
        (grams == null ||
            grams < 0 ||
            (grams == 0 && kind != DebugTreatmentKind.calculator))) {
      return null;
    }
    if (kind == DebugTreatmentKind.calculator && dose == 0 && grams == 0) {
      return null;
    }
    if (kind == DebugTreatmentKind.extendedCarbs &&
        (duration == null ||
            duration <= 0 ||
            Duration(minutes: duration).inMinutes != duration)) {
      return null;
    }
    return DebugTreatmentEvent(
      kind: kind,
      insulin: kind.hasInsulin ? dose : null,
      carbs: kind.hasCarbs ? grams : null,
      minutes: kind == DebugTreatmentKind.extendedCarbs ? duration : null,
    );
  }

  @override
  String get eventName => type;

  @override
  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    if (insulin != null) 'insulin': insulin,
    if (carbs != null) 'carbs': carbs,
    if (minutes != null) 'minutes': minutes,
  };
}
