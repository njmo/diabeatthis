import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/drift/providers/database_provider.dart';
import 'drift_ingredient_origin_repository.dart';
import 'drift_local_ingredient_search_repository.dart';
import 'drift_selected_catalog_ingredient_store.dart';
import 'firebase_ingredient_catalog_repository.dart';
import 'http_catalog_callable_transport.dart';
import 'ingredient_catalog_repository.dart';
import 'ingredient_origin_repository.dart';
import 'local_ingredient_search_repository.dart';
import 'select_ingredient_search_item_use_case.dart';
import 'selected_catalog_ingredient_store.dart';
import 'unified_ingredient_search_use_case.dart';

final catalogRepositoryProvider = Provider<IngredientCatalogRepository>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return FirebaseIngredientCatalogRepository(
    HttpCatalogCallableTransport(
      client: client,
      projectId: Firebase.apps.isEmpty ? '' : Firebase.app().options.projectId,
      appCheckToken: () async =>
          Firebase.apps.isEmpty ? null : FirebaseAppCheck.instance.getToken(),
    ),
  );
});
final localIngredientSearchRepositoryProvider =
    Provider<LocalIngredientSearchRepository>(
      (ref) =>
          DriftLocalIngredientSearchRepository(ref.watch(databaseProvider)),
    );
final selectedCatalogIngredientStoreProvider =
    Provider<SelectedCatalogIngredientStore>(
      (ref) => DriftSelectedCatalogIngredientStore(ref.watch(databaseProvider)),
    );
final unifiedIngredientSearchUseCaseProvider =
    Provider<UnifiedIngredientSearchUseCase>(
      (ref) => UnifiedIngredientSearchUseCase(
        local: ref.watch(localIngredientSearchRepositoryProvider),
        catalog: ref.watch(catalogRepositoryProvider),
      ),
    );

final selectIngredientSearchItemUseCaseProvider =
    Provider<SelectIngredientSearchItemUseCase>(
      (ref) => SelectIngredientSearchItemUseCase(
        catalog: ref.watch(catalogRepositoryProvider),
        store: ref.watch(selectedCatalogIngredientStoreProvider),
      ),
    );

final ingredientOriginRepositoryProvider = Provider<IngredientOriginRepository>(
  (ref) => DriftIngredientOriginRepository(ref.watch(databaseProvider)),
);
