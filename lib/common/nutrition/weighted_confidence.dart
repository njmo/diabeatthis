/// Returns no estimate when a positive contribution has unknown confidence.
/// Zero contributions have no influence; an empty total has no confidence.
double? weightedConfidence(
  Iterable<({double weight, double? confidence})> contributions,
) {
  var total = 0.0;
  var weighted = 0.0;
  for (final item in contributions) {
    if (!item.weight.isFinite || item.weight < 0) return null;
    if (item.weight == 0) continue;
    final confidence = item.confidence;
    if (confidence == null ||
        !confidence.isFinite ||
        confidence < 0 ||
        confidence > 1) {
      return null;
    }
    total += item.weight;
    weighted += item.weight * confidence;
  }
  return total > 0 ? weighted / total : null;
}
