import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/drift/database_impl.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../../core/llm/analysis_llm_provider.dart';
import '../../../../core/llm/firebase_ai_llm_client.dart';
import '../../../../core/llm/local_llm_client.dart';
import '../drafts/ingredient_draft.dart';
import 'ingredient_icon_service.dart';

final ingredientIconClientProvider = Provider<LocalLlmClient>(
  (ref) => const FirebaseAiLlmClient(
    modelName: analysisFirebaseModel,
    gateway: FirebaseAiGenerateContentGateway(
      maxOutputTokens: 64,
      thinkingBudget: 0,
    ),
  ),
);

final ingredientIconServiceProvider = Provider<IngredientIconService>(
  (ref) =>
      IngredientIconService(client: ref.watch(ingredientIconClientProvider)),
);

final ingredientIconSuggestionProvider = FutureProvider.autoDispose
    .family<String?, (String, String?)>(
      (ref, product) => ref
          .watch(ingredientIconServiceProvider)
          .suggest(product.$1, product.$2),
    );

void prefetchIngredientIcon(Ref ref, IngredientDraft draft) {
  if (draft.iconAssetPath != null) return;
  final service = ref.read(ingredientIconServiceProvider);
  final id = draft.getIngredientIdOrNull();
  if (id == null) {
    unawaited(service.suggest(draft.name, draft.brand));
  } else {
    unawaited(() async {
      try {
        final path = await service.suggest(draft.name, draft.brand);
        if (path == null || !ref.mounted) return;
        await persistIngredientIcon(
          ref.read(databaseProvider),
          service,
          id,
          draft.name,
          draft.brand,
        );
      } catch (_) {
        // Optional classification must not initialize or block storage on failure.
      }
    }());
  }
}

Future<void> persistIngredientIcon(
  DatabaseImpl db,
  IngredientIconService service,
  int id,
  String name,
  String? brand,
) async {
  try {
    final path = await service.suggest(name, brand);
    if (path == null) return;
    await (db.update(db.ingredient)..where(
          (row) =>
              row.id.equals(id) &
              row.name.equals(name) &
              row.iconAssetPath.isNull() &
              (brand == null ? row.brand.isNull() : row.brand.equals(brand)),
        ))
        .write(IngredientCompanion(iconAssetPath: Value(path)));
  } catch (_) {
    // A late result cannot break saving or overwrite a changed ingredient.
  }
}
