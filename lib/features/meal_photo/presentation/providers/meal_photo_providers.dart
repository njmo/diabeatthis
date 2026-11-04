import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/ai/ai_client_providers.dart';
import '../../../../common/ingredient_catalog/drift_ingredient_origin_repository.dart';
import '../../../../common/ingredient_catalog/drift_selected_catalog_ingredient_store.dart';
import '../../../../common/ingredient_catalog/ingredient_catalog_providers.dart';
import '../../../../common/l10n/language.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../meals/data/domain/use_cases/save_meal_draft_use_case.dart';
import '../../data/catalog_meal_photo_candidate_repository.dart';
import '../../data/drift_meal_photo_draft_ingredient_resolver.dart';
import '../../data/drift_meal_photo_local_ingredient_reader.dart';
import '../../data/local_llm_meal_photo_recognition_client.dart';
import '../../data/meal_photo_draft_settings.dart';
import '../../data/meal_photo_ingredient_creation_check.dart';
import '../../data/prepared_meal_photo_saver.dart';
import '../../data/save_meal_draft_photo_writer.dart';
import '../../domain/use_cases/propose_meal_from_photo_use_case.dart';
import '../controllers/meal_photo_controller.dart';

final mealPhotoCandidatesProvider =
    Provider<CatalogMealPhotoCandidateRepository>(
      (ref) => CatalogMealPhotoCandidateRepository(
        searchUseCase: ref.watch(unifiedIngredientSearchUseCaseProvider),
        catalog: ref.watch(catalogRepositoryProvider),
        local: DriftMealPhotoLocalIngredientReader(ref.watch(databaseProvider)),
        selectedStore: DriftSelectedCatalogIngredientStore(
          ref.watch(databaseProvider),
        ),
        origins: DriftIngredientOriginRepository(ref.watch(databaseProvider)),
        onCatalogFailure: (error) => developer.log(
          'Catalog candidates unavailable; continuing with local candidates',
          name: 'meal_photo',
          error: error,
        ),
      ),
    );

/// The page owns the controller lifecycle and supplies its selected meal category.
final mealPhotoControllerFactoryProvider =
    Provider<MealPhotoController Function(MealPhotoDraftSettings Function())>((
      ref,
    ) {
      final db = ref.watch(databaseProvider);
      final candidates = ref.watch(mealPhotoCandidatesProvider);
      final client = ref.watch(aiPhotoClientProvider);
      final resolver = DriftMealPhotoDraftIngredientResolver(
        db: db,
        local: DriftMealPhotoLocalIngredientReader(db),
        catalogStore: DriftSelectedCatalogIngredientStore(db),
      );
      final writer = SaveMealDraftPhotoWriter(
        saveMealDraft: SaveMealDraftUseCase(ref),
        language: () => lang,
      );
      return (settings) => MealPhotoController(
        propose: ProposeMealFromPhotoUseCase(
          client: LocalLlmMealPhotoRecognitionClient(client),
          candidates: candidates,
        ),
        checkIngredientCreation: MealPhotoIngredientCreationCheck(
          db,
          DriftSelectedCatalogIngredientStore(db),
        ).call,
        saver: PreparedMealPhotoSaver(
          ingredients: resolver,
          writer: writer,
          settings: settings,
          runAtomic: (action) => db.transaction(action),
        ),
      );
    });
