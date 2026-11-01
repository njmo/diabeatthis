import 'ai_provider_capabilities.dart';
import 'ai_provider_kind.dart';

class AiConfiguration {
  const AiConfiguration({
    this.provider = AiProviderKind.firebase,
    this.firebaseModel = 'gemini-2.5-flash',
    this.openAiModel = 'gpt-6-luna',
    this.chatGptModel = '',
    this.imageProvider,
    this.imageGenerationEnabled = true,
  });

  final AiProviderKind provider;
  final AiProviderKind? imageProvider;
  final bool imageGenerationEnabled;
  bool get canGenerateImages =>
      imageGenerationEnabled &&
      supportsAiImageGeneration(effectiveImageProvider);
  AiProviderKind get effectiveImageProvider => imageProvider ?? provider;
  bool get requiresApiKey =>
      provider == AiProviderKind.openAi ||
      (imageGenerationEnabled &&
          effectiveImageProvider == AiProviderKind.openAi);
  final String firebaseModel;
  final String openAiModel;
  final String chatGptModel;

  AiConfiguration normalizeImageGeneration() =>
      imageGenerationEnabled &&
          !supportsAiImageGeneration(effectiveImageProvider)
      ? copyWith(imageGenerationEnabled: false)
      : this;

  String get model => switch (provider) {
    AiProviderKind.firebase => firebaseModel,
    AiProviderKind.openAi => openAiModel,
    AiProviderKind.chatGpt => chatGptModel,
  };

  AiConfiguration copyWith({
    AiProviderKind? provider,
    String? firebaseModel,
    String? openAiModel,
    String? chatGptModel,
    AiProviderKind? imageProvider,
    bool inheritImageProvider = false,
    bool? imageGenerationEnabled,
  }) => AiConfiguration(
    provider: provider ?? this.provider,
    imageGenerationEnabled:
        imageGenerationEnabled ?? this.imageGenerationEnabled,
    imageProvider: inheritImageProvider
        ? null
        : imageProvider ?? this.imageProvider,
    firebaseModel: firebaseModel ?? this.firebaseModel,
    openAiModel: openAiModel ?? this.openAiModel,
    chatGptModel: chatGptModel ?? this.chatGptModel,
  );

  Map<String, Object> toJson() => {
    'provider': provider.name,
    'imageGenerationEnabled': imageGenerationEnabled,
    if (imageProvider != null) 'imageProvider': imageProvider!.name,
    'firebaseModel': firebaseModel.trim(),
    'openAiModel': openAiModel.trim(),
    'chatGptModel': chatGptModel.trim(),
  };

  factory AiConfiguration.fromJson(Map<String, dynamic> json) {
    final provider = AiProviderKind.values.firstWhere(
      (value) => value.name == json['provider'],
      orElse: () => throw const FormatException('Unknown AI provider'),
    );
    return AiConfiguration(
      provider: provider,
      imageGenerationEnabled: json['imageGenerationEnabled'] as bool? ?? true,
      imageProvider: json['imageProvider'] == null
          ? null
          : AiProviderKind.values.firstWhere(
              (value) => value.name == json['imageProvider'],
              orElse: () =>
                  throw const FormatException('Unknown image provider'),
            ),
      firebaseModel: json['firebaseModel'] as String? ?? 'gemini-2.5-flash',
      openAiModel: json['openAiModel'] as String? ?? 'gpt-6-luna',
      chatGptModel: json['chatGptModel'] as String? ?? '',
    );
  }
}
