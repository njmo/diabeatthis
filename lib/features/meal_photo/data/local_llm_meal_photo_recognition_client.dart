import '../../../core/llm/local_llm_client.dart';
import '../domain/models/meal_photo_candidate.dart';
import '../domain/models/meal_photo_input.dart';
import '../domain/ports/meal_photo_recognition_client.dart';
import 'meal_photo_prompt.dart';
import 'meal_photo_response_schema.dart';

class LocalLlmMealPhotoRecognitionClient implements MealPhotoRecognitionClient {
  const LocalLlmMealPhotoRecognitionClient(
    this.client, {
    this.prompt = const MealPhotoPrompt(),
    this.timeout = const Duration(seconds: 90),
    this.maxOutputTokens = 8192,
  });
  final LocalLlmClient client;
  final MealPhotoPrompt prompt;
  final Duration timeout;
  final int maxOutputTokens;
  @override
  Future<String> describe(MealPhotoInput input) async {
    input.validate();
    return (await client.generate(
      LocalLlmRequest(
        prompt: prompt.build(input),
        imagePaths: input.imagePaths,
        timeout: timeout,
        maxOutputTokens: maxOutputTokens,
        responseJsonSchema: MealPhotoResponseSchema.value,
      ),
    )).text;
  }

  @override
  Future<String> resolve(
    MealPhotoInput input,
    String descriptionResponse,
    Map<String, List<MealPhotoCandidate>> candidates,
  ) async {
    input.validate();
    return (await client.generate(
      LocalLlmRequest(
        prompt: prompt.build(
          input,
          descriptionResponse: descriptionResponse,
          candidates: candidates,
        ),
        imagePaths: input.imagePaths,
        timeout: timeout,
        maxOutputTokens: maxOutputTokens,
        responseJsonSchema: MealPhotoResponseSchema.value,
      ),
    )).text;
  }
}
