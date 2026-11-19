import 'package:intl/intl.dart';

import '../../l10n/language.dart';
import '../domain/family_treatment_carbs.dart';

/// Localized, display-only rendering of a low-treatment request.
///
/// Shared by the conversation UI and the notification presenter. It never
/// changes the wire text or any clinical value; it only formats a snapshot.

/// Treatment snapshots carry unit codes (`piece`, `portion`, `g`, `ml`).
/// Legacy Polish labels are accepted for food choices built elsewhere.
String familyTreatmentUnitLabel(String unit, AppLocalizations lang) =>
    switch (unit) {
      'piece' || 'szt.' => lang.familyChatUnitPiece,
      'portion' || 'porcji' => lang.familyChatUnitPortion,
      _ => unit,
    };

/// The request body in [lang]. [carbs] is the nutrition value; the recorded
/// whole grams follow the shared clinical rounding.
String familyTreatmentText(
  AppLocalizations lang, {
  required String product,
  required double quantity,
  required String unit,
  required double carbs,
}) {
  final separator = NumberFormat.decimalPattern(
    lang.localeName,
  ).symbols.DECIMAL_SEP;
  return lang.familyChatLowTreatmentMessage(
    quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toString(),
    familyTreatmentUnitLabel(unit, lang),
    product,
    carbs == carbs.roundToDouble()
        ? carbs.toInt().toString()
        : carbs.toString().replaceAll('.', separator),
    carbs >= .5 ? familyTreatmentRecordedCarbs(carbs) : 0,
  );
}

/// Renders a verified structured snapshot, or returns null when the snapshot
/// is missing or malformed so callers keep the original message text.
/// Never parses message text.
String? familyTreatmentSnapshotText(Object? snapshot, AppLocalizations lang) {
  if (snapshot is! Map) return null;
  final product = snapshot['foodName'];
  final quantity = snapshot['quantity'];
  final unit = snapshot['unit'];
  if (product is! String ||
      product.trim().isEmpty ||
      quantity is! num ||
      !quantity.isFinite ||
      quantity <= 0 ||
      unit is! String ||
      !const {'piece', 'portion', 'g', 'ml'}.contains(unit)) {
    return null;
  }
  double? positive(Object? value) =>
      value is num && value.isFinite && value > 0 ? value.toDouble() : null;
  final perUnit = positive(snapshot['carbsPerUnit']);
  final grams = positive(snapshot['gramsPerUnit']);
  final per100 = positive(snapshot['carbsPer100g']);
  final carbs =
      positive(snapshot['carbs']) ??
      (unit == 'portion'
          ? perUnit == null
                ? null
                : quantity * perUnit
          : grams == null || per100 == null
          ? null
          : quantity * grams * per100 / 100);
  if (carbs == null || carbs < .5 || carbs > 10000) return null;
  return familyTreatmentText(
    lang,
    product: product,
    quantity: quantity.toDouble(),
    unit: unit,
    carbs: carbs,
  );
}
