import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/llm/local_llm_client.dart';
import 'ai_connection_providers.dart';
import 'ai_image_client.dart';
import 'ai_service.dart';
import 'ai_service_clients.dart';
import 'ai_settings_controller.dart';
import 'configured_ai_service.dart';

final aiServiceProvider = Provider<AiService>(
  (ref) => ConfiguredAiService(
    configuration: ref.watch(aiSettingsControllerProvider.future),
    factory: ref.watch(aiClientFactoryProvider),
  ),
);

final aiImageClientProvider = Provider<AiImageClient>(
  (ref) => AiServiceImageClient(ref.watch(aiServiceProvider)),
);
final aiAnalysisClientProvider = Provider<LocalLlmClient>(
  (ref) => AiServiceTextClient(
    ref.watch(aiServiceProvider),
    AiAnalysisPurpose.analysis,
  ),
);
final aiPhotoClientProvider = Provider<LocalLlmClient>(
  (ref) => AiServiceTextClient(
    ref.watch(aiServiceProvider),
    AiAnalysisPurpose.photo,
  ),
);
final aiIconSuggestionClientProvider = Provider<LocalLlmClient>(
  (ref) => AiServiceTextClient(
    ref.watch(aiServiceProvider),
    AiAnalysisPurpose.iconSuggestion,
  ),
);
