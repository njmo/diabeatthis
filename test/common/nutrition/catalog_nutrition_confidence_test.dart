import 'package:diabeatthis/common/nutrition/catalog_nutrition_confidence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'unassessed catalog confidence defaults to medium and user assessments stay unchanged',
    () {
      expect(catalogNutritionConfidence(null, assessed: false), .5);
      expect(catalogNutritionConfidence(0, assessed: false), .5);
      expect(catalogNutritionConfidence(.25, assessed: true), .25);
      expect(catalogNutritionConfidence(.95, assessed: true), .95);
    },
  );
}
