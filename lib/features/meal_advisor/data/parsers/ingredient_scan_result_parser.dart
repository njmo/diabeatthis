import 'dart:convert';

import '../models/ingredient_scan_result.dart';

class IngredientScanResultParser {
  const IngredientScanResultParser();

  IngredientScanResult parse(String rawResponse) {
    final jsonText = _extractJsonObject(rawResponse);
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Ingredient scan response must be a JSON object',
      );
    }
    return parseMap(decoded);
  }

  IngredientScanResult parseMap(Map<String, dynamic> json) {
    return IngredientScanResult(
      name: _readString(json, 'name'),
      brand: _readString(json, 'brand'),
      nutritionPer100g: _parseNutritionPer100g(json),
      portions: _parsePortions(json),
    );
  }

  NutritionPer100g _parseNutritionPer100g(Map<String, dynamic> json) {
    final source = json['nutritionPer100g'];
    if (source is! Map<String, dynamic>) {
      return const NutritionPer100g(
        carbs: null,
        fat: null,
        protein: null,
        fiber: null,
      );
    }

    return NutritionPer100g(
      carbs: _readNonNegativeNumber(source, 'carbs'),
      fat: _readNonNegativeNumber(source, 'fat'),
      protein: _readNonNegativeNumber(source, 'protein'),
      fiber: _readNonNegativeNumber(source, 'fiber'),
    );
  }

  List<RecognizedPortion> _parsePortions(Map<String, dynamic> json) {
    final rawPortions = json['portions'];
    if (rawPortions is! List) {
      return const [];
    }

    return rawPortions
        .whereType<Map<String, dynamic>>()
        .map((portion) {
          return RecognizedPortion(
            name: _readString(portion, 'name'),
            unitHint: _readString(portion, 'unitHint'),
            grams: _readPositiveNumber(portion, 'grams'),
            source: _readString(portion, 'source'),
          );
        })
        .toList(growable: false);
  }

  String _extractJsonObject(String rawResponse) {
    final trimmed = rawResponse.trim();
    final firstBrace = trimmed.indexOf('{');
    final lastBrace = trimmed.lastIndexOf('}');
    if (firstBrace < 0 || lastBrace < firstBrace) {
      throw const FormatException(
        'Ingredient scan response does not contain JSON',
      );
    }
    return trimmed.substring(firstBrace, lastBrace + 1);
  }

  String? _readString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  double? _readNonNegativeNumber(Map<String, dynamic> json, String key) {
    final value = _parseNumber(json[key]);
    if (value == null || value < 0) {
      return null;
    }
    return value;
  }

  double? _readPositiveNumber(Map<String, dynamic> json, String key) {
    final value = _parseNumber(json[key]);
    if (value == null || value <= 0) {
      return null;
    }
    return value;
  }

  double? _parseNumber(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is! String) {
      return null;
    }

    final normalized = value.trim().replaceAll(',', '.');
    final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(normalized);
    if (match == null) {
      return null;
    }
    return double.tryParse(match.group(0)!);
  }
}
