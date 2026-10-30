import 'dart:io';

import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/features/ingredients/data/icons/food_icon_assets.dart';
import 'package:diabeatthis/features/ingredients/data/icons/ingredient_icon_service.dart';
import 'package:diabeatthis/features/ingredients/data/icons/wicked_food_icon_assets.dart';
import 'package:flutter_test/flutter_test.dart';

class TortillaIconClient implements LocalLlmClient {
  LocalLlmRequest? request;

  @override
  Future<LocalLlmResponse> generate(LocalLlmRequest request) async {
    this.request = request;
    return const LocalLlmResponse(text: '{"icon":"wicked_flour_tortillas"}');
  }
}

void main() {
  test('Wicked catalog ships valid local WebP files and readable names', () {
    expect(WickedFoodIconAssets.paths.length, greaterThanOrEqualTo(694));
    for (final entry in WickedFoodIconAssets.paths.entries) {
      final bytes = File(entry.value).readAsBytesSync();
      expect(String.fromCharCodes(bytes.take(4)), 'RIFF', reason: entry.key);
      expect(
        String.fromCharCodes(bytes.skip(8).take(4)),
        'WEBP',
        reason: entry.key,
      );
      expect(FoodIconAssets.contains(entry.value), isTrue);
      expect(FoodIconAssets.nameFor(entry.key), isNotEmpty);
    }
    expect(File('assets/icons/wicked_food/NOTICE.txt').existsSync(), isTrue);
    expect(FoodIconAssets.contains('assets/icons/food/apple.png'), isTrue);
  });

  test(
    'AI can select a specific tortilla and return its complete asset path',
    () async {
      final client = TortillaIconClient();
      final path = await IngredientIconService(
        client: client,
      ).suggest('8 mini tortillas', 'el tequito');
      expect(path, 'assets/icons/wicked_food/flour-tortillas.webp');
      expect(client.request!.prompt, contains('wicked_flour_tortillas'));
      expect(client.request!.imagePaths, isEmpty);
    },
  );
}
