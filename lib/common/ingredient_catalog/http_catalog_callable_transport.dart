import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'catalog_callable_transport.dart';
import 'ingredient_catalog_exception.dart';

class HttpCatalogCallableTransport implements CatalogCallableTransport {
  const HttpCatalogCallableTransport({
    required this.client,
    required this.projectId,
    required this.appCheckToken,
    this.timeout = const Duration(seconds: 15),
  });
  final http.Client client;
  final String projectId;
  final Future<String?> Function() appCheckToken;
  final Duration timeout;

  @override
  Future<Map<String, dynamic>> call(
    String function,
    Map<String, Object?> data,
  ) async {
    if (!{'searchIngredients', 'getCatalogIngredient'}.contains(function)) {
      throw ArgumentError.value(function, 'function');
    }
    try {
      if (projectId.isEmpty) {
        throw const IngredientCatalogException(
          IngredientCatalogFailure.unavailable,
        );
      }
      final token = await appCheckToken().timeout(timeout);
      if (token == null || token.isEmpty) {
        throw const IngredientCatalogException(
          IngredientCatalogFailure.unauthorized,
        );
      }
      final response = await client
          .post(
            Uri.https(
              'europe-west1-$projectId.cloudfunctions.net',
              '/$function',
            ),
            headers: {
              'Content-Type': 'application/json',
              'X-Firebase-AppCheck': token,
            },
            body: jsonEncode({'data': data}),
          )
          .timeout(timeout);
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const IngredientCatalogException(
          IngredientCatalogFailure.unauthorized,
        );
      }
      if (response.statusCode == 404 || response.statusCode >= 500) {
        throw const IngredientCatalogException(
          IngredientCatalogFailure.unavailable,
        );
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['error'] is Map) {
        final status = (body['error'] as Map)['status'];
        throw IngredientCatalogException(
          status == 'FAILED_PRECONDITION'
              ? IngredientCatalogFailure.staleCursor
              : IngredientCatalogFailure.unavailable,
        );
      }
      if (response.statusCode != 200) {
        throw const IngredientCatalogException(
          IngredientCatalogFailure.unavailable,
        );
      }
      return Map<String, dynamic>.from(body['result'] as Map);
    } on IngredientCatalogException {
      rethrow;
    } on FormatException {
      throw const IngredientCatalogException(
        IngredientCatalogFailure.invalidResponse,
      );
    } on TypeError {
      throw const IngredientCatalogException(
        IngredientCatalogFailure.invalidResponse,
      );
    } catch (_) {
      throw const IngredientCatalogException(
        IngredientCatalogFailure.unavailable,
      );
    }
  }
}
