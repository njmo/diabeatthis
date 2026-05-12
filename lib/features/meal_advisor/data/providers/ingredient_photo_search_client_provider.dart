import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/llm/providers/firebase_ai_llm_client_provider.dart';
import '../clients/ingredient_photo_search_client.dart';
import '../clients/local_llm_ingredient_photo_search_client.dart';

part 'ingredient_photo_search_client_provider.g.dart';

@riverpod
IngredientPhotoSearchClient ingredientPhotoSearchClient(Ref ref) {
  return LocalLlmIngredientPhotoSearchClient(
    llmClient: ref.watch(firebaseAiLlmClientProvider),
    timeout: const Duration(seconds: 20),
  );
}
