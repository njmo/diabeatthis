import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/data/provider/shared_prefs_provider.dart';

enum ApplicationDeviceMode { patient, caregiver }

const applicationDeviceModeKey = 'application-device-mode';

ApplicationDeviceMode deviceModeFromPreferences(SharedPreferences prefs) =>
    prefs.getString(applicationDeviceModeKey) ==
        ApplicationDeviceMode.caregiver.name
    ? ApplicationDeviceMode.caregiver
    : ApplicationDeviceMode.patient;

Future<ApplicationDeviceMode> loadApplicationDeviceMode() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  return deviceModeFromPreferences(prefs);
}

final applicationDeviceModeProvider = FutureProvider<ApplicationDeviceMode>(
  (ref) async =>
      deviceModeFromPreferences(await ref.watch(sharedPrefsProvider.future)),
);
