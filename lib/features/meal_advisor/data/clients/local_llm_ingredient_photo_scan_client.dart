import '../../../../core/llm/local_llm_client.dart';
import '../models/ingredient_photo_scan_input.dart';
import '../prompts/ingredient_photo_scan_prompt.dart';
import 'ingredient_photo_scan_client.dart';

class LocalLlmIngredientPhotoScanClient implements IngredientPhotoScanClient {
  final LocalLlmClient llmClient;
  final String prompt;
  final Duration? timeout;

  const LocalLlmIngredientPhotoScanClient({
    required this.llmClient,
    this.prompt = ingredientPhotoScanPrompt,
    this.timeout,
  });

  @override
  Future<String> scan(IngredientPhotoScanInput input) async {
    final response = await llmClient.generate(
      LocalLlmRequest(
        prompt: prompt,
        imagePaths: [
          if (input.frontPhotoPath != null) input.frontPhotoPath!,
          if (input.nutritionLabelPhotoPath != null)
            input.nutritionLabelPhotoPath!,
        ],
        timeout: timeout,
      ),
    );
    return response.text;
  }
}
