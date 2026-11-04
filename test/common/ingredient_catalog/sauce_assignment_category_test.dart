import 'package:diabeatthis/common/ingredient_catalog/ingredient_match_score.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared cream descriptor does not turn cheese into a sauce match', () {
    expect(
      ingredientNameMatchScore(
        'cream sauce',
        'Serek śmietankowy',
        'Cream cheese',
      ),
      0,
    );
    expect(
      ingredientNameMatchScore(
        'Sos śmietanowy',
        'Serek śmietankowy',
        'Cream cheese',
      ),
      0,
    );
    expect(
      ingredientNameMatchScore('cream sauce', 'Sos śmietanowy', 'Cream sauce'),
      1,
    );
  });
}
