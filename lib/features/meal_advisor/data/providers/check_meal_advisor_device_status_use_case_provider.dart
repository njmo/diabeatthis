import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/use_cases/check_meal_advisor_device_status_use_case.dart';

final checkMealAdvisorDeviceStatusUseCaseProvider =
    Provider<CheckMealAdvisorDeviceStatusUseCase>(
      (ref) => const CheckMealAdvisorDeviceStatusUseCase(),
    );
