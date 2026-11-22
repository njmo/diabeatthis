import 'dart:convert';

import 'meal_add_on_bolus_context.dart';

typedef MealAddOnProgress = ({
  String originalStatus,
  bool awaitingBolus,
  bool? additionalServing,
  bool bolusBeforeExtra,
});

MealAddOnProgress addOnProgressForContext(MealAddOnBolusContext context) => (
  originalStatus: context.originalStatus,
  awaitingBolus: context.showCalculatorAction,
  additionalServing: context.additionalServing,
  bolusBeforeExtra:
      context.bolusBeforeExtra ?? context.acceptedWizardKeys.isNotEmpty,
);

MealAddOnProgress? readMirroredAddOnProgress(Object? value) {
  if (value is! String) return null;
  try {
    final data = jsonDecode(value);
    if (data is Map &&
        data['originalStatus'] is String &&
        _isFlag(data['awaitingBolus']) &&
        (data['additionalServing'] == null ||
            _isFlag(data['additionalServing'])) &&
        _isFlag(data['bolusBeforeExtra'])) {
      return (
        originalStatus: data['originalStatus'] as String,
        awaitingBolus: data['awaitingBolus'] == 1,
        additionalServing: data['additionalServing'] == null
            ? null
            : data['additionalServing'] == 1,
        bolusBeforeExtra: data['bolusBeforeExtra'] == 1,
      );
    }
  } on FormatException {
    return null;
  }
  return null;
}

bool _isFlag(Object? value) => value == 0 || value == 1;

extension MealAddOnProgressStage on MealAddOnProgress {
  bool get waitingForExtraBolus => awaitingBolus && (additionalServing ?? true);
}
