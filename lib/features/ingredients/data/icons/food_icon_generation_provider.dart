import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/ai/ai_client_providers.dart';
import 'food_icon_generation_service.dart';

final foodIconGenerationServiceProvider = Provider<FoodIconGenerationService>(
  (ref) => FoodIconGenerationService(
    generate: ref.watch(aiImageClientProvider).generate,
  ),
);
