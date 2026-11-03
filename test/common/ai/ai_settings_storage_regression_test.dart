import 'package:diabeatthis/common/ai/ai_client_factory.dart';
import 'package:diabeatthis/common/ai/ai_configuration.dart';
import 'package:diabeatthis/common/ai/ai_connection_providers.dart';
import 'package:diabeatthis/common/ai/ai_provider_kind.dart';
import 'package:diabeatthis/common/ai/save_ai_settings_use_case.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/regression/controlled_preferences.dart';
import 'helpers/recording_ai_credential_store.dart';

void main() {
  for (final previous in [null, 'previous-key']) {
    for (final throws in [false, true]) {
      test(
        'failed preference write restores credentials; previous=$previous throws=$throws',
        () async {
          final prefs = ControlledPreferences()..acceptWrites = false;
          if (throws) prefs.writeError = StateError('Scripted storage failure');
          final credentials = RecordingAiCredentialStore();
          if (previous != null) {
            credentials.values[openAiApiKeyStorageKey] = previous;
          }
          final container = ProviderContainer(
            overrides: [
              sharedPrefsProvider.overrideWith((ref) async => prefs),
              aiCredentialStoreProvider.overrideWithValue(credentials),
            ],
          );
          addTearDown(container.dispose);
          await expectLater(
            container.read(saveAiSettingsUseCaseProvider)(
              const AiConfiguration(provider: AiProviderKind.openAi),
              apiKey: ' replacement-key ',
            ),
            throwsStateError,
          );
          expect(credentials.values[openAiApiKeyStorageKey], previous);
          expect(credentials.writes.first.value, 'replacement-key');
          expect(credentials.reads, [openAiApiKeyStorageKey]);
          expect(prefs.values, isEmpty);
          expect(prefs.writes, hasLength(1));
          expect(
            prefs.writes.single.value.toString(),
            isNot(contains('replacement-key')),
          );
        },
      );
    }
  }
}
