import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/data/provider/shared_prefs_provider.dart';

enum ApplicationDeviceMode { patient, caregiver }

const applicationDeviceModeKey = 'application-device-mode';

bool get isCaregiverOnlyPlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

bool hasSavedCaregiverMode(SharedPreferences prefs) =>
    prefs.getString(applicationDeviceModeKey) ==
    ApplicationDeviceMode.caregiver.name;

ApplicationDeviceMode deviceModeFromPreferences(SharedPreferences prefs) =>
    isCaregiverOnlyPlatform || hasSavedCaregiverMode(prefs)
    ? ApplicationDeviceMode.caregiver
    : ApplicationDeviceMode.patient;

Future<ApplicationDeviceMode> loadApplicationDeviceMode() async {
  if (isCaregiverOnlyPlatform) return ApplicationDeviceMode.caregiver;
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  return deviceModeFromPreferences(prefs);
}

final applicationDeviceModeProvider = FutureProvider<ApplicationDeviceMode>(
  (ref) async =>
      deviceModeFromPreferences(await ref.watch(sharedPrefsProvider.future)),
);
