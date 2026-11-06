import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/app_mode/application_device_mode.dart';
import '../../../core/data_sources/nightscout/nightscout_connection_fingerprint.dart';
import '../../../core/data_sources/nightscout/providers/nightscout_url_provider.dart';
import 'caregiver_refresh_state.dart';

/// Never presents a cached snapshot as belonging to an unresolved/new source.
final caregiverVisibleStateProvider = Provider<CaregiverRefreshState>((ref) {
  final modeState = ref.watch(applicationDeviceModeProvider);
  final urlState = ref.watch(nightscoutUrlProvider);
  final tokenState = ref.watch(nightscoutTokenProvider);
  if (modeState.isLoading ||
      modeState.hasError ||
      urlState.isLoading ||
      urlState.hasError ||
      tokenState.isLoading ||
      tokenState.hasError) {
    return const CaregiverRefreshState();
  }
  final mode = modeState.asData?.value;
  final url = urlState.asData?.value;
  final token = tokenState.asData?.value;
  final state = ref.watch(caregiverRefreshStateProvider);
  if (mode != ApplicationDeviceMode.caregiver ||
      url == null ||
      token == null ||
      state.connection != nightscoutConnectionFingerprint(url, token)) {
    return const CaregiverRefreshState();
  }
  return state;
});
