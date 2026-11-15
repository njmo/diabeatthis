import 'package:diabeatthis/common/setup/domain/validate_setup_module_use_case.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_connection_verification.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_token_validator.dart';
import 'package:diabeatthis/core/data_sources/nightscout/providers/nightscout_connection_check_provider.dart';
import 'package:diabeatthis/features/settings/application/validate_setup_nightscout_use_case.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class SetupTokenValidator extends NightscoutTokenValidator {
  final List<bool> requests = [];
  bool fail = false;
  NightscoutTokenIssue? issue;
  @override
  Future<void> validate({
    required String url,
    required String token,
    bool requireTreatmentWrite = true,
  }) async {
    requests.add(requireTreatmentWrite);
    if (issue != null) throw NightscoutTokenValidationException(issue!);
    if (fail) {
      throw const NightscoutTokenValidationException(
        NightscoutTokenIssue.treatmentAccess,
      );
    }
  }
}

void main() {
  test('maps every token issue and local validation failure', () async {
    final validator = SetupTokenValidator();
    final container = ProviderContainer(
      overrides: [
        nightscoutTokenValidatorProvider.overrideWithValue(validator),
        nightscoutConnectionCheckProvider.overrideWithValue(
          ({required String url, required String token}) async {},
        ),
      ],
    );
    addTearDown(container.dispose);
    final check = container.read(validateSetupNightscoutProvider);
    expect(
      await check('bad-url', 'token', true),
      SetupNightscoutVerification.invalidUrl,
    );
    expect(
      await check('https://example.com', '  ', true),
      SetupNightscoutVerification.tokenRequired,
    );
    expect(validator.requests, isEmpty);
    for (final entry in {
      NightscoutTokenIssue.required: SetupNightscoutVerification.tokenRequired,
      NightscoutTokenIssue.invalid: SetupNightscoutVerification.invalidToken,
      NightscoutTokenIssue.treatmentAccess:
          SetupNightscoutVerification.writeAccessMissing,
      NightscoutTokenIssue.unavailable: SetupNightscoutVerification.unavailable,
      NightscoutTokenIssue.invalidUrl: SetupNightscoutVerification.invalidUrl,
    }.entries) {
      validator.issue = entry.key;
      expect(await check('https://example.com', 'token', true), entry.value);
    }
  });

  test(
    'anonymous read succeeds and connection exceptions become unavailable',
    () async {
      var offline = false;
      final container = ProviderContainer(
        overrides: [
          nightscoutConnectionCheckProvider.overrideWithValue(({
            required String url,
            required String token,
          }) async {
            if (offline) throw StateError('offline');
          }),
        ],
      );
      addTearDown(container.dispose);
      final check = container.read(validateSetupNightscoutProvider);
      expect(
        await check('https://example.com', '', false),
        SetupNightscoutVerification.readVerified,
      );
      offline = true;
      expect(
        await check('https://example.com', '', false),
        SetupNightscoutVerification.unavailable,
      );
      expect(
        container
            .read(nightscoutConnectionVerificationProvider)
            .matches(url: 'https://example.com', token: ''),
        isFalse,
      );
    },
  );

  test(
    'verification is scoped to exact credentials, time and clock direction',
    () {
      var now = DateTime.utc(2026, 11, 6);
      final verification = NightscoutConnectionVerification(now: () => now);
      verification.remember(url: ' https://nightscout.test ', token: ' token ');
      expect(
        verification.matches(url: 'https://nightscout.test', token: 'token'),
        isTrue,
      );
      expect(
        verification.matches(url: 'https://other.test', token: 'token'),
        isFalse,
      );
      expect(
        verification.matches(url: 'https://nightscout.test', token: 'changed'),
        isFalse,
      );
      now = now.add(const Duration(minutes: 6));
      expect(
        verification.matches(url: 'https://nightscout.test', token: 'token'),
        isFalse,
      );
      now = DateTime.utc(2026, 11, 5);
      expect(
        verification.matches(url: 'https://nightscout.test', token: 'token'),
        isFalse,
      );
    },
  );
  test(
    'Next checks status and token permissions before recording verification',
    () async {
      final validator = SetupTokenValidator();
      var checks = 0;
      final container = ProviderContainer(
        overrides: [
          nightscoutConnectionCheckProvider.overrideWithValue(({
            required String url,
            required String token,
          }) async {
            checks++;
          }),
          nightscoutTokenValidatorProvider.overrideWithValue(validator),
        ],
      );
      addTearDown(container.dispose);
      final check = container.read(validateSetupNightscoutProvider);
      expect(
        await check('https://nightscout.test', 'token', true),
        SetupNightscoutVerification.readWriteVerified,
      );
      expect(checks, 1);
      expect(validator.requests, [true]);
      final verification = container.read(
        nightscoutConnectionVerificationProvider,
      );
      expect(
        verification.matches(url: 'https://nightscout.test', token: 'token'),
        isTrue,
      );
      validator.fail = true;
      expect(
        await check('https://nightscout.test', 'token', true),
        SetupNightscoutVerification.writeAccessMissing,
      );
      expect(
        verification.matches(url: 'https://nightscout.test', token: 'token'),
        isFalse,
      );
    },
  );
  test(
    'a supplied read token is checked even without upload options',
    () async {
      final validator = SetupTokenValidator();
      final container = ProviderContainer(
        overrides: [
          nightscoutConnectionCheckProvider.overrideWithValue(
            ({required String url, required String token}) async {},
          ),
          nightscoutTokenValidatorProvider.overrideWithValue(validator),
        ],
      );
      addTearDown(container.dispose);
      await container.read(validateSetupNightscoutProvider)(
        'https://nightscout.test',
        'read-token',
        false,
      );
      expect(validator.requests, [false]);
    },
  );
}
