import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'food_icon_generation_service.dart';

final foodIconGenerationServiceProvider = Provider<FoodIconGenerationService>(
  (ref) => const FoodIconGenerationService(),
);
