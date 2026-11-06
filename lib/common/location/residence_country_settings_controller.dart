import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/provider/shared_prefs_provider.dart';
import 'residence_country_provider.dart';

final residenceCountrySettingsControllerProvider = Provider(
  (ref) => ResidenceCountrySettingsController(ref),
);

class ResidenceCountrySettingsController {
  const ResidenceCountrySettingsController(this.ref);
  final Ref ref;
  Future<void> save(String? country) async {
    final value = country?.trim();
    if (value != null && value.isEmpty) {
      throw ArgumentError('A country is required');
    }
    final prefs = await ref.read(sharedPrefsProvider.future);
    final saved = value == null
        ? await prefs.remove(residenceCountryKey)
        : await prefs.setString(residenceCountryKey, value);
    if (!saved) throw StateError('Country preference was not saved');
    if (ref.mounted) ref.invalidate(residenceCountryOverrideProvider);
  }
}
