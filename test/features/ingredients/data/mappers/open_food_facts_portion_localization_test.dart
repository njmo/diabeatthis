import 'dart:ui';

import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/features/ingredients/data/mappers/open_food_facts_product_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'missing portion names follow the language and source names are preserved',
    () {
      addTearDown(() => LanguageStrings.setSelectedLocale(const Locale('pl')));
      const mapper = OpenFoodFactsProductMapper();
      LanguageStrings.setSelectedLocale(const Locale('en'));
      final english = mapper.readPortions({'serving_quantity': 20}).single;
      expect(english.name, 'Portion');
      expect(english.unitHint, 'portion');
      expect(english.grams, 20);
      LanguageStrings.setSelectedLocale(const Locale('pl'));
      final polish = mapper.readPortions({'serving_quantity': 20}).single;
      expect(polish.name, 'Porcja');
      expect(polish.unitHint, 'porcja');
      final source = mapper.readPortions({
        'serving_quantity': 20,
        'serving_size': 'Custom serving',
      }).single;
      expect(source.name, 'Custom serving');
    },
  );
}
