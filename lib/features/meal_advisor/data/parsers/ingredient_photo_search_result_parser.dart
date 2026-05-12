import 'dart:convert';

import '../models/ingredient_photo_search_result.dart';

class IngredientPhotoSearchResultParser {
  const IngredientPhotoSearchResultParser();

  IngredientPhotoSearchResult parse(String rawResponse) {
    final decoded = jsonDecode(_extractJsonObject(rawResponse));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Ingredient photo search response must be a JSON object',
      );
    }

    return IngredientPhotoSearchResult(
      names: _readNames(decoded),
      brand: _readString(decoded, 'brand'),
    );
  }

  List<String> _readNames(Map<String, dynamic> json) {
    final names = json['names'];
    if (names is List) {
      return names
          .whereType<String>()
          .map((name) => name.trim().toLowerCase())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList(growable: false);
    }

    final name = _readString(json, 'name');
    return name == null ? const [] : [name.toLowerCase()];
  }

  String _extractJsonObject(String rawResponse) {
    final trimmed = rawResponse.trim();
    final firstBrace = trimmed.indexOf('{');
    final lastBrace = trimmed.lastIndexOf('}');
    if (firstBrace < 0 || lastBrace < firstBrace) {
      throw const FormatException(
        'Ingredient photo search response does not contain JSON',
      );
    }
    return trimmed.substring(firstBrace, lastBrace + 1);
  }

  String? _readString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim().toLowerCase();
    }
    return null;
  }
}
