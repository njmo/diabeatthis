import 'package:diabeatthis/common/ingredient_catalog/drift_ingredient_origin_repository.dart';
import 'package:diabeatthis/common/ingredient_catalog/drift_selected_catalog_ingredient_store.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_search_item.dart';
import 'package:diabeatthis/common/ingredient_catalog/unified_ingredient_search_use_case.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/meal_photo/data/catalog_meal_photo_candidate_repository.dart';
import 'package:diabeatthis/features/meal_photo/data/drift_meal_photo_draft_ingredient_resolver.dart';
import 'package:diabeatthis/features/meal_photo/data/drift_meal_photo_local_ingredient_reader.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_review_item.dart';
import 'package:diabeatthis/features/meal_photo/domain/services/meal_photo_proposal_parser.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../common/ingredient_catalog/catalog_persistence_test.dart'
    show catalogItem;
import 'catalog_meal_photo_candidate_repository_test.dart'
    show PhotoCatalog, PhotoLocalSearch;
import 'meal_photo_proposal_test.dart' as fixtures;

void main() {
  test(
    'renamed remote result resolves the existing immutable revision before review and saves',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final store = DriftSelectedCatalogIngredientStore(db);
      final original = catalogItem(revision: 'r1');
      final id = await store.mirror(original);
      final catalog = PhotoCatalog();
      final reader = DriftMealPhotoLocalIngredientReader(db);
      final repository = CatalogMealPhotoCandidateRepository(
        searchUseCase: UnifiedIngredientSearchUseCase(
          local: PhotoLocalSearch(),
          catalog: catalog,
        ),
        catalog: catalog,
        local: reader,
        selectedStore: store,
        origins: DriftIngredientOriginRepository(db),
      );
      final candidate = await repository.resolve(
        IngredientSearchItem(
          identity: original.identity,
          name: 'Renamed food',
          sourceRevision: 'r2',
        ),
        languageCode: 'en',
      );
      expect(candidate.localIngredientId, id);
      expect(candidate.catalogRevision, 'r1');
      expect(candidate.name, original.name);
      expect(catalog.reads, 0);
      final item = MealPhotoReviewItem.fromProposal(
        const MealPhotoProposalParser()
            .parse(fixtures.proposal())
            .itemized
            .single,
      ).assign(candidate);
      await expectLater(
        DriftMealPhotoDraftIngredientResolver(
          db: db,
          local: reader,
          catalogStore: store,
        ).resolve(item),
        completes,
      );
    },
  );
}
