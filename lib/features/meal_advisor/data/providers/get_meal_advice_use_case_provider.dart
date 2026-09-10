import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/use_cases/get_meal_advice_use_case.dart';

final getMealAdviceUseCaseProvider = Provider<GetMealAdviceUseCase>(
  (ref) => const GetMealAdviceUseCase(),
);
