import 'dart:convert';

import 'package:diabeatthis/features/ingredients/data/clients/open_food_facts_product_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('OpenFoodFactsProductClient', () {
    test('uses v2 product endpoint with app user agent', () async {
      late Uri requestedUri;
      late Map<String, String> requestedHeaders;
      final client = OpenFoodFactsProductClient(
        httpClient: MockClient((request) async {
          requestedUri = request.url;
          requestedHeaders = request.headers;
          return http.Response(jsonEncode({'status': 1}), 200);
        }),
      );

      await client.fetchProduct('5900512350080');

      expect(requestedUri.path, '/api/v2/product/5900512350080.json');
      expect(requestedUri.queryParameters['fields'], contains('nutriments'));
      expect(requestedHeaders['user-agent'], openFoodFactsUserAgent);
    });
  });
}
