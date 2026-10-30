import 'dart:convert';

class IngredientPhotoSearchResult {
  final List<String> names;
  final String? brand;

  const IngredientPhotoSearchResult({required this.names, required this.brand});

  bool get hasCandidates =>
      names.isNotEmpty || (brand?.trim().isNotEmpty ?? false);

  String get candidatesKey {
    final normalizedNames = names
        .map((part) => part.trim().toLowerCase())
        .where((part) => part.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final normalizedBrand = brand?.trim().toLowerCase();

    return jsonEncode({
      'names': normalizedNames,
      if (normalizedBrand != null && normalizedBrand.isNotEmpty)
        'brand': normalizedBrand,
    });
  }

  static IngredientPhotoSearchCandidates? tryParseCandidatesKey(String key) {
    if (key.trim().isEmpty) {
      return null;
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(key);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) {
      return null;
    }

    final namesValue = decoded['names'];
    final names = namesValue is List
        ? namesValue
              .whereType<String>()
              .map((name) => name.trim().toLowerCase())
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList(growable: false)
        : const <String>[];
    final brandValue = decoded['brand'];
    final brand = brandValue is String && brandValue.trim().isNotEmpty
        ? brandValue.trim().toLowerCase()
        : null;

    return IngredientPhotoSearchCandidates(names: names, brand: brand);
  }
}

class IngredientPhotoSearchCandidates {
  final List<String> names;
  final String? brand;

  const IngredientPhotoSearchCandidates({
    required this.names,
    required this.brand,
  });

  bool get hasCandidates => names.isNotEmpty || brand != null;
}
