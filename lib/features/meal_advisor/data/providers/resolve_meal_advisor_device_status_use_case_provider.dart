import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data_sources/providers/source_repository_providers.dart';
import '../../../dashboard/data/providers/device_status_ui_provider.dart';
import '../../domain/use_cases/resolve_meal_advisor_device_status_use_case.dart';
import 'check_meal_advisor_device_status_use_case_provider.dart';

final resolveMealAdvisorDeviceStatusUseCaseProvider =
    Provider<ResolveMealAdvisorDeviceStatusUseCase>(
      (ref) => ResolveMealAdvisorDeviceStatusUseCase(
        loadRepository: () =>
            ref.read(deviceStatusHistoryRepositoryProvider.future),
        readCurrentStatus: () =>
            ref.mounted ? ref.read(deviceStatusUiProvider) : null,
        checkStatus: ref.watch(checkMealAdvisorDeviceStatusUseCaseProvider),
      ),
    );
