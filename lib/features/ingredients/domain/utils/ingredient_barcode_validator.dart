class IngredientBarcodeValidator {
  const IngredientBarcodeValidator();

  String? normalizeValidBarcode(String rawValue) {
    final value = rawValue.trim();
    if (!RegExp(r'^\d{8,14}$').hasMatch(value)) {
      return null;
    }
    if (!hasValidGtinCheckDigit(value)) {
      return null;
    }
    return value;
  }

  bool hasValidGtinCheckDigit(String value) {
    if (!RegExp(r'^\d{8}(\d{4,6})?$').hasMatch(value)) {
      return false;
    }

    final checkDigit = int.parse(value[value.length - 1]);
    var sum = 0;
    var weight = 3;
    for (var i = value.length - 2; i >= 0; i--) {
      sum += int.parse(value[i]) * weight;
      weight = weight == 3 ? 1 : 3;
    }

    final expectedCheckDigit = (10 - (sum % 10)) % 10;
    return checkDigit == expectedCheckDigit;
  }
}
