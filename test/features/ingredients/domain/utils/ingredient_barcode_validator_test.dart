import 'package:diabeatthis/features/ingredients/domain/utils/ingredient_barcode_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IngredientBarcodeValidator', () {
    const validator = IngredientBarcodeValidator();

    test('accepts valid EAN and UPC barcodes', () {
      expect(validator.normalizeValidBarcode('5900512350080'), '5900512350080');
      expect(validator.normalizeValidBarcode('5449000000996'), '5449000000996');
      expect(validator.normalizeValidBarcode('036000291452'), '036000291452');
    });

    test('rejects barcode with invalid check digit', () {
      expect(validator.normalizeValidBarcode('5900512350081'), isNull);
      expect(validator.normalizeValidBarcode('5449000000997'), isNull);
    });

    test('rejects values that are not GTIN-like digits', () {
      expect(validator.normalizeValidBarcode('abc'), isNull);
      expect(validator.normalizeValidBarcode('1234567'), isNull);
      expect(validator.normalizeValidBarcode('123456789012345'), isNull);
    });
  });
}
