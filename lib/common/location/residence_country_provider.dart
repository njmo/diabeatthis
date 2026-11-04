import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/provider/shared_prefs_provider.dart';

const residenceCountryKey = 'residence-country';

/// Explicit user context; never inferred from app language or device location.
final residenceCountryProvider = FutureProvider<String?>((ref) async {
  final prefs = await ref.watch(sharedPrefsProvider.future);
  final value = prefs.getString(residenceCountryKey)?.trim();
  return value == null || value.isEmpty ? null : value;
});
