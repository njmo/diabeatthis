import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/provider/shared_prefs_provider.dart';
import 'resolve_residence_country_use_case.dart';

const residenceCountryKey = 'residence-country';

final deviceCountryLocalesProvider = Provider<List<Locale>>(
  (ref) => PlatformDispatcher.instance.locales,
);
final residenceCountryOverrideProvider = FutureProvider<String?>((ref) async {
  final prefs = await ref.watch(sharedPrefsProvider.future);
  final value = prefs.getString(residenceCountryKey)?.trim();
  return value == null || value.isEmpty ? null : value;
});

/// Explicit overrides take precedence over the system region; never infer from UI language or GPS.
final residenceCountryProvider = FutureProvider<String?>((ref) async {
  final locales = ref.watch(deviceCountryLocalesProvider);
  final override = await ref.watch(residenceCountryOverrideProvider.future);
  return const ResolveResidenceCountryUseCase()(
    override: override,
    locales: locales,
  );
});
