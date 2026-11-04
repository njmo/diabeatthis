import 'dart:math' as math;

/// Removes only floating-point noise around nonzero whole nutrition values.
/// The tolerance is 64 machine epsilons times max(1, abs(value)); the unit
/// floor applies only to nonzero integer boundaries. Values whose nearest
/// integer is zero stay untouched, so a real tiny positive amount rounds up.
/// This is a calculation/display boundary; persisted nutrition remains exact.
double stableMacroValue(num value) {
  final amount = value.toDouble();
  if (!amount.isFinite || amount == 0) return amount;
  final nearest = amount.roundToDouble();
  if (nearest == 0) return amount;
  const machineEpsilon = 2.220446049250313e-16;
  final tolerance = 64 * machineEpsilon * math.max(1.0, amount.abs());
  return (amount - nearest).abs() <= tolerance ? nearest : amount;
}

/// Cancels only representation noise when comparing the same macro quantity.
/// Cancellation uses 64 machine epsilons times the larger operand magnitude,
/// without the integer-boundary unit floor: tiny genuine quantities
/// compared with zero therefore remain present.
double stableMacroDifference(num left, num right) {
  final a = stableMacroValue(left);
  final b = stableMacroValue(right);
  final difference = a - b;
  if (!a.isFinite || !b.isFinite) return difference;
  const machineEpsilon = 2.220446049250313e-16;
  final tolerance = 64 * machineEpsilon * math.max(a.abs(), b.abs());
  return difference.abs() <= tolerance ? 0 : difference;
}

int stableMacroCeil(num value) => stableMacroValue(value).ceil();

extension StableMacroCeiling on num {
  int ceilMacro() => stableMacroCeil(this);
}
