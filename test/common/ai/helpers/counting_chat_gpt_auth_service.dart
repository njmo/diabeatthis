import 'package:diabeatthis/common/ai/auth/chat_gpt_auth_service.dart';

class CountingChatGptAuthService extends ChatGptAuthService {
  CountingChatGptAuthService({required super.credentials});

  int accessTokenCalls = 0;

  @override
  Future<String> accessToken() async {
    accessTokenCalls++;
    throw StateError(
      'Image generation must not request ChatGPT authorization.',
    );
  }
}
