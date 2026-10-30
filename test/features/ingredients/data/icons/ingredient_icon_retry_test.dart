import 'dart:async';

import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/features/ingredients/data/icons/ingredient_icon_service.dart';
import 'package:flutter_test/flutter_test.dart';

class RetryIconClient implements LocalLlmClient {
  final responses = <Completer<LocalLlmResponse>>[];

  @override
  Future<LocalLlmResponse> generate(LocalLlmRequest request) {
    final response = Completer<LocalLlmResponse>();
    responses.add(response);
    return response.future;
  }
}

void main() {
  for (final failedResponse in [
    null,
    '{"icon":"generic"}',
    '{"icon":"unknown"}',
  ]) {
    test(
      'failed selection can retry instead of caching $failedResponse',
      () async {
        final client = RetryIconClient();
        final service = IngredientIconService(client: client);
        final first = service.suggest('Jogurt Twix', 'Danone');
        if (failedResponse == null) {
          client.responses.first.completeError(StateError('Offline'));
        } else {
          client.responses.first.complete(
            LocalLlmResponse(text: failedResponse),
          );
        }
        await first;
        expect(service.cached('Jogurt Twix', 'Danone'), isNull);
        final retry = service.suggest('Jogurt Twix', 'Danone');
        expect(client.responses, hasLength(2));
        client.responses.last.complete(
          const LocalLlmResponse(text: '{"icon":"wicked_yogurt"}'),
        );
        expect(await retry, 'assets/icons/wicked_food/yogurt.webp');
      },
    );
  }

  test(
    'explicit AI selection refreshes a cached icon but shares an in-flight request',
    () async {
      final client = RetryIconClient();
      final service = IngredientIconService(client: client);
      final first = service.suggest('Jogurt M&Ms', null);
      client.responses.first.complete(
        const LocalLlmResponse(text: '{"icon":"chocolate"}'),
      );
      await first;
      final refreshed = service.suggest('Jogurt M&Ms', null, refresh: true);
      final simultaneous = service.suggest('Jogurt M&Ms', null, refresh: true);
      expect(client.responses, hasLength(2));
      client.responses.last.complete(
        const LocalLlmResponse(text: '{"icon":"wicked_yogurt"}'),
      );
      expect(await refreshed, 'assets/icons/wicked_food/yogurt.webp');
      expect(await simultaneous, await refreshed);
      expect(service.cached('Jogurt M&Ms', null), await refreshed);
    },
  );
}
