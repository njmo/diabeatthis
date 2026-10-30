import 'dart:async';

import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/llm/llm_output_limit_exception.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/features/ingredients/data/icons/ingredient_icon_service.dart';
import 'package:diabeatthis/features/ingredients/presentation/widgets/ingredient_icon_error_message.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class FailingIconClient implements LocalLlmClient {
  const FailingIconClient(this.error);
  final Object error;
  @override
  Future<LocalLlmResponse> generate(LocalLlmRequest request) async =>
      throw error;
}

void main() {
  final language = lookupAppLocalizations(const Locale('pl'));
  final errors = <Object, String>{
    const LlmRequestException(
      failure: LlmRequestFailure.quotaExceeded,
      message: 'Quota',
    ): language.ingredientAiQuotaExceeded,
    const LlmOutputLimitException('partial output'):
        language.ingredientIconOutputLimit,
    const FormatException('invalid JSON'):
        language.ingredientIconInvalidResponse,
    TimeoutException('timeout'): language.ingredientAiTimeout,
  };
  for (final entry in errors.entries) {
    test(
      'manual selection reports ${entry.key.runtimeType} while background stays optional',
      () async {
        final service = IngredientIconService(
          client: FailingIconClient(entry.key),
        );
        final result = await service.lookup('Jogurt', null);
        expect(result.path, isNull);
        expect(result.error, same(entry.key));
        expect(ingredientIconErrorMessage(language, result.error), entry.value);
        expect(await service.suggest('Jogurt', null), isNull);
      },
    );
  }
}
