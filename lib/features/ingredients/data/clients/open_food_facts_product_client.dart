import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/logger/logger.dart';

const openFoodFactsUserAgent = 'Diabeatthis/1.0 (https://diabeatthis.pl)';
final Uri openFoodFactsBaseUri = Uri.parse('https://world.openfoodfacts.org');

class OpenFoodFactsProductClient with Logging {
  final http.Client? httpClient;
  final Duration timeout;

  OpenFoodFactsProductClient({
    this.httpClient,
    this.timeout = const Duration(seconds: 10),
  });

  Future<Map<String, dynamic>> fetchProduct(String barcode) async {
    final uri = openFoodFactsBaseUri.replace(
      path: '/api/v2/product/$barcode.json',
      queryParameters: {
        'fields': [
          'status',
          'product_name',
          'product_name_pl',
          'generic_name',
          'generic_name_pl',
          'brands',
          'brands_tags',
          'nutriments',
          'serving_quantity',
          'serving_size',
        ].join(','),
      },
    );
    final client = httpClient ?? http.Client();
    try {
      final response = await client
          .get(uri, headers: const {'user-agent': openFoodFactsUserAgent})
          .timeout(timeout);
      logD('Open Food Facts response ${response.statusCode} for $barcode');
      if (response.statusCode != 200) {
        throw OpenFoodFactsRequestException(response.statusCode);
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'Open Food Facts response must be an object.',
        );
      }
      return decoded;
    } catch (error, stackTrace) {
      logE(
        'Open Food Facts request failed for $barcode at $uri',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } finally {
      if (httpClient == null) {
        client.close();
      }
    }
  }
}

class OpenFoodFactsRequestException implements Exception {
  final int statusCode;

  const OpenFoodFactsRequestException(this.statusCode);

  @override
  String toString() {
    return 'OpenFoodFactsRequestException(statusCode: $statusCode)';
  }
}

class OpenFoodFactsProductNotFoundException implements Exception {
  final String barcode;

  const OpenFoodFactsProductNotFoundException(this.barcode);

  @override
  String toString() {
    return 'OpenFoodFactsProductNotFoundException(barcode: $barcode)';
  }
}
