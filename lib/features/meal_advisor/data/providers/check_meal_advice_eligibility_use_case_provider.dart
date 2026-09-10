import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data_sources/providers/source_repository_providers.dart';
import '../../domain/use_cases/check_meal_advice_eligibility_use_case.dart';

final checkMealAdviceEligibilityUseCaseProvider =
    Provider<CheckMealAdviceEligibilityUseCase>(
      (ref) => CheckMealAdviceEligibilityUseCase(
        loadRepository: () => ref.read(glucoseHistoryRepositoryProvider.future),
      ),
    );
