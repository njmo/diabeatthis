import 'package:diabeatthis/common/ingredient_catalog/firebase_ingredient_catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalog_contract_test.dart' as fixtures;

void main() {
  test(
    'Polish original is preserved without inventing an English translation',
    () async {
      final data = fixtures.fixture();
      final source = data['ingredient'] as Map<String, dynamic>;
      source['name'] = 'Ryż gotowany';
      source['languageCode'] = 'pl';
      data['englishName'] = null;
      final repository = FirebaseIngredientCatalogRepository(
        fixtures.CatalogFixtureTransport(data),
      );
      final item = await repository.get(
        fixtures.catalogIdentity,
        languageCode: 'pl',
      );
      expect(item.name, 'Ryż gotowany');
      expect(item.sourceName, 'Ryż gotowany');
      expect(item.englishName, isNull);
      expect(item.languageCode, 'pl');
      expect(item.netCarbsPer100g, 26);
    },
  );

  test(
    'English display translation does not change source name or nutrition revision',
    () async {
      final data = fixtures.fixture();
      final source = data['ingredient'] as Map<String, dynamic>;
      source['name'] = 'Ryż gotowany';
      source['languageCode'] = 'pl';
      data['englishName'] = 'Cooked rice';
      final repository = FirebaseIngredientCatalogRepository(
        fixtures.CatalogFixtureTransport(data),
      );
      final polish = await repository.get(
        fixtures.catalogIdentity,
        languageCode: 'pl',
      );
      final display = data['display'] as Map<String, dynamic>;
      display['name'] = 'Cooked rice';
      display['languageCode'] = 'en';
      final english = await repository.get(
        fixtures.catalogIdentity,
        languageCode: 'en',
      );
      expect(english.name, 'Cooked rice');
      expect(english.sourceName, polish.sourceName);
      expect(english.englishName, 'Cooked rice');
      expect(english.revision, polish.revision);
      expect(english.netCarbsPer100g, polish.netCarbsPer100g);
    },
  );
}
