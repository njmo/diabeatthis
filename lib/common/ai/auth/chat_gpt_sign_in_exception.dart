import '../../../core/llm/local_llm_client.dart';
import 'chat_gpt_sign_in_stage.dart';

/// Contains only a safe stage and category, never an OAuth response or token.
class ChatGptSignInException extends LlmRequestException {
  const ChatGptSignInException({required this.stage, required super.failure})
    : super(message: 'ChatGPT sign-in did not complete.');

  final ChatGptSignInStage stage;
}
