import 'dart:async';
import 'dart:io';

import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/features/ingredients/data/icons/food_icon_assets.dart';
import 'package:diabeatthis/features/ingredients/data/icons/ingredient_icon_service.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeIconClient implements LocalLlmClient {
  final response = Completer<LocalLlmResponse>();
  final requests = <LocalLlmRequest>[];

  @override
  Future<LocalLlmResponse> generate(LocalLlmRequest request) {
    requests.add(request);
    return response.future;
  }
}

void main() {
  test('every selectable icon exists locally and a license is bundled', () {
    expect(FoodIconAssets.paths.length, greaterThan(100));
    for (final path in FoodIconAssets.paths.values) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
    expect(
      File('assets/icons/food/LICENSE.txt').readAsStringSync(),
      contains('MIT'),
    );
  });

  test(
    'deduplicates pending requests and caches the complete local asset path',
    () async {
      final client = FakeIconClient();
      final service = IngredientIconService(client: client);
      final first = service.suggest(' Burger ', null);
      final second = service.suggest('burger', null);
      expect(client.requests, hasLength(1));
      expect(client.requests.single.imagePaths, isEmpty);
      client.response.complete(
        const LocalLlmResponse(text: '{"icon":"hamburger"}'),
      );
      expect(await first, 'assets/icons/food/hamburger.png');
      expect(await second, await first);
      expect(await service.suggest('burger', null), await first);
      expect(client.requests, hasLength(1));
      expect(service.cached('burger', null), await first);
    },
  );

  test(
    'reference dish names are classified normally instead of forced to a plate',
    () async {
      final client = FakeIconClient();
      final service = IngredientIconService(client: client);
      final result = service.suggest('Zupa w restauracji', null);
      client.response.complete(
        const LocalLlmResponse(text: '```json\n{"icon":"soup"}\n```'),
      );
      expect(await result, 'assets/icons/food/soup.png');
    },
  );

  for (final text in [
    '{"icon":"../../unknown.png"}',
    '{"icon":"not-bundled"}',
    'invalid',
    '[]',
  ]) {
    test('rejects invalid or unbundled selection: $text', () async {
      final client = FakeIconClient();
      final service = IngredientIconService(client: client);
      final result = service.suggest('Food', null);
      client.response.complete(LocalLlmResponse(text: text));
      expect(await result, isNull);
    });
  }

  test(
    'unavailable AI is optional and resolves to the generic fallback',
    () async {
      final service = IngredientIconService(
        client: const LocalLlmUnavailableClient(),
      );
      expect(await service.suggest('Food', null), isNull);
    },
  );
}
