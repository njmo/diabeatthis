import 'ai_provider_kind.dart';

enum AiCapability { analysis, imageInput, imageGeneration }

const aiProviderCapabilities = {
  AiProviderKind.firebase: {
    AiCapability.analysis,
    AiCapability.imageInput,
    AiCapability.imageGeneration,
  },
  AiProviderKind.openAi: {
    AiCapability.analysis,
    AiCapability.imageInput,
    AiCapability.imageGeneration,
  },
  AiProviderKind.chatGpt: {AiCapability.analysis, AiCapability.imageInput},
};

bool supportsAiImageGeneration(AiProviderKind provider) =>
    aiProviderCapabilities[provider]!.contains(AiCapability.imageGeneration);
