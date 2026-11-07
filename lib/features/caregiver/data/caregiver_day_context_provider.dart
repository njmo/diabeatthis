import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/app_mode/application_device_mode.dart';
import '../../../common/auth/google_authentication_providers.dart';
import '../../../common/history/load_nightscout_day_context_use_case.dart';
import '../../../core/data_sources/nightscout/providers/nightscout_repository_provider.dart';
import '../../day_analysis/domain/models/day_context.dart';

typedef CaregiverDayScope = ({
  DateTime date,
  String uid,
  String? owner,
  String? source,
  int revision,
});

/// A visible-day request follows its account, family, date and NS connection.
final caregiverDayContextProvider = FutureProvider.autoDispose
    .family<DayContext, CaregiverDayScope>((ref, scope) async {
      final account = ref.watch(googleAccountProvider);
      if (account.isLoading ||
          account.hasError ||
          account.asData?.value?.uid != scope.uid) {
        throw StateError('Caregiver account changed.');
      }
      final mode = await ref.watch(applicationDeviceModeProvider.future);
      if (mode != ApplicationDeviceMode.caregiver) {
        throw StateError('Caregiver mode is required.');
      }
      final repository = await ref.watch(nightscoutRepositoryProvider.future);
      return LoadNightscoutDayContextUseCase(repository)(date: scope.date);
    });
