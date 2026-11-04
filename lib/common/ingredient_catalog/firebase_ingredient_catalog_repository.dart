import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/domain/model/carbs_label_mode.dart';
import 'catalog_callable_transport.dart';
import 'catalog_ingredient.dart';
import 'catalog_search_page.dart';
import 'ingredient_catalog_exception.dart';
import 'ingredient_catalog_repository.dart';
import 'ingredient_identity.dart';
import 'ingredient_search_item.dart';

class FirebaseIngredientCatalogRepository
    implements IngredientCatalogRepository {
  const FirebaseIngredientCatalogRepository(this.transport);
  final CatalogCallableTransport transport;

  @override
  Future<CatalogSearchPage> search({
    required String query,
    required String languageCode,
    int limit = 20,
    String? cursor,
  }) async {
    final data = await transport.call('searchIngredients', {
      'query': query,
      'languageCode': languageCode,
      'limit': limit,
      'cursor': cursor,
    });
    try {
      final rows = data['items'] as List;
      return CatalogSearchPage(
        releaseId: requiredString(data, 'releaseId'),
        nextCursor: data['nextCursor'] as String?,
        items: rows.map((row) {
          final item = Map<String, dynamic>.from(row as Map);
          return IngredientSearchItem(
            identity: remoteIdentity(item['identity']),
            name: requiredString(item, 'name'),
            englishName: item['englishName'] as String?,
            details: item['details'] as String? ?? '',
            languageCode: requiredString(item, 'displayLanguageCode'),
            iconAssetPath: safeIcon(item['iconAssetPath']),
          );
        }).toList(),
      );
    } catch (_) {
      throw const IngredientCatalogException(
        IngredientCatalogFailure.invalidResponse,
      );
    }
  }

  @override
  Future<CatalogIngredient> get(
    IngredientIdentity identity, {
    String languageCode = 'en',
  }) async {
    if (identity.source != IngredientSource.firebase || !identity.isValid) {
      throw ArgumentError.value(identity, 'identity');
    }
    final data = await transport.call('getCatalogIngredient', {
      'sourceId': identity.sourceId,
      'languageCode': languageCode,
    });
    try {
      if (remoteIdentity(data['identity']) != identity) {
        throw const FormatException();
      }
      final item = Map<String, dynamic>.from(data['ingredient'] as Map);
      final display = Map<String, dynamic>.from(data['display'] as Map);
      if (item['id'] != identity.sourceId ||
          item['sourceIngredientId'] != identity.sourceId ||
          item['nutritionBasisGrams'] != 100 ||
          item['isReference'] != false) {
        throw const FormatException();
      }
      final mode = switch (item['carbsLabelMode']) {
        'eu' => CarbsLabelMode.eu,
        'non_eu' => CarbsLabelMode.nonEu,
        _ => throw const FormatException(),
      };
      if (item['carbohydrateDefinition'] !=
          (mode == CarbsLabelMode.nonEu
              ? 'total_including_fiber'
              : 'available_excluding_fiber')) {
        throw const FormatException();
      }
      final carbs = nutrient(item, 'carbsPer100g');
      final fiber = nutrient(item, 'fiberPer100g');
      final fat = nutrient(item, 'fatPer100g');
      final protein = nutrient(item, 'proteinPer100g');
      if (mode == CarbsLabelMode.nonEu && fiber > carbs) {
        throw const FormatException();
      }
      final revision = sha256
          .convert(
            utf8.encode(
              jsonEncode([
                identity.sourceId,
                requiredString(item, 'name'),
                carbs,
                fiber,
                fat,
                protein,
                mode.name,
                item['kcalPer100g'],
              ]),
            ),
          )
          .toString();
      return CatalogIngredient(
        identity: identity,
        name: requiredString(display, 'name'),
        englishName: data.containsKey('englishName')
            ? data['englishName'] as String?
            : (item['languageCode'] ?? 'en') == 'en'
            ? requiredString(item, 'name')
            : null,
        sourceName: requiredString(item, 'name'),
        revision: revision,
        carbsPer100g: carbs,
        fiberPer100g: fiber,
        fatPer100g: fat,
        proteinPer100g: protein,
        carbsLabelMode: mode,
        details: display['details'] as String? ?? '',
        languageCode: requiredString(display, 'languageCode'),
        iconAssetPath: safeIcon(item['iconAssetPath']),
        kcalPer100g: item['kcalPer100g'] == null
            ? null
            : nutrient(item, 'kcalPer100g', maximum: 1000),
      );
    } catch (_) {
      throw const IngredientCatalogException(
        IngredientCatalogFailure.invalidResponse,
      );
    }
  }

  static String requiredString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException();
    }
    return value;
  }

  static double nutrient(
    Map<String, dynamic> map,
    String key, {
    double maximum = 100,
  }) {
    final value = map[key];
    if (value is! num || !value.isFinite || value < 0 || value > maximum) {
      throw const FormatException();
    }
    return value.toDouble();
  }

  static IngredientIdentity remoteIdentity(dynamic value) {
    final identity = IngredientIdentity.fromJson(
      Map<String, dynamic>.from(value as Map),
    );
    if (identity.source != IngredientSource.firebase ||
        !RegExp(r'^usda_[1-9][0-9]*$').hasMatch(identity.sourceId)) {
      throw const FormatException();
    }
    return identity;
  }

  static String? safeIcon(dynamic value) =>
      value is String &&
          RegExp(
            r'^assets/icons/(food|wicked_food)/[a-zA-Z0-9_-]+\.png$',
          ).hasMatch(value)
      ? value
      : null;
}
