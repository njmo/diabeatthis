import '../../../../core/llm/local_llm_client.dart';
import '../models/ingredient_photo_scan_input.dart';
import '../prompts/ingredient_photo_search_prompt.dart';
import 'ingredient_photo_search_client.dart';

class LocalLlmIngredientPhotoSearchClient
    implements IngredientPhotoSearchClient {
  final LocalLlmClient llmClient;
  final String prompt;
  final Duration? timeout;

  const LocalLlmIngredientPhotoSearchClient({
    required this.llmClient,
    this.prompt = ingredientPhotoSearchPrompt,
    this.timeout,
  });

  @override
  Future<String> search(IngredientPhotoScanInput input) async {
    if (input.frontPhotoPath == null) {
      throw StateError('Ingredient photo search requires a front photo.');
    }

    final response = await llmClient.generate(
      LocalLlmRequest(
        prompt: prompt,
        imagePaths: [input.frontPhotoPath!],
        timeout: timeout,
      ),
    );
    return response.text;
  }
}
