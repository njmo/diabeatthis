import 'package:diabeatthis/core/llm/local_llm_client.dart';

class OpenAiTestImageLoader implements LlmImageLoader {
  OpenAiTestImageLoader(this.images);

  final List<LlmImageData> images;
  List<String>? paths;

  @override
  Future<List<LlmImageData>> loadAll(List<String> imagePaths) async {
    paths = imagePaths;
    return images;
  }
}
