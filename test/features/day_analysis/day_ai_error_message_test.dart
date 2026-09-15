import 'dart:async';

import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_ai_error_message.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in ['pl', 'en']) {
    test(
      'Day AI errors are localized and hide response contents ($locale)',
      () async {
        final lang = await AppLocalizations.delegate.load(Locale(locale));
        expect(
          dayAiErrorMessage(lang, const FormatException('private response')),
          lang.dayAiInvalidResponse,
        );
        expect(
          dayAiErrorMessage(lang, TimeoutException('private request')),
          lang.dayAiTimeout,
        );
        final expected = {
          LlmRequestFailure.network: lang.dayAiNetworkError,
          LlmRequestFailure.unauthorized: lang.dayAiUnauthorized,
          LlmRequestFailure.quotaExceeded: lang.dayAiQuotaExceeded,
          LlmRequestFailure.timeout: lang.dayAiTimeout,
          LlmRequestFailure.unavailable: lang.dayAiUnavailable,
        };
        for (final entry in expected.entries) {
          expect(
            dayAiErrorMessage(
              lang,
              LlmRequestException(
                failure: entry.key,
                message: 'private provider response',
              ),
            ),
            entry.value,
          );
        }
        expect(
          dayAiErrorMessage(lang, StateError('private details')),
          lang.dayAiFailed,
        );
      },
    );
  }
}
