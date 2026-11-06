import 'dart:ui';

/// A locale region is a default context, not a claim about physical residence.
class ResolveResidenceCountryUseCase {
  const ResolveResidenceCountryUseCase();
  String? call({String? override, required List<Locale> locales}) {
    final explicit = override?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    for (final locale in locales) {
      final region = locale.countryCode?.toUpperCase();
      if (region != null && RegExp(r'^[A-Z]{2}$').hasMatch(region)) {
        return region;
      }
    }
    return null;
  }
}
