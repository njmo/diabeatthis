import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/setup/domain/validate_setup_module_use_case.dart';
import '../../../core/data_sources/nightscout/nightscout_connection_verification.dart';
import '../../../core/data_sources/nightscout/nightscout_token_validator.dart';
import '../../../core/data_sources/nightscout/providers/nightscout_connection_check_provider.dart';

final validateSetupNightscoutProvider = Provider<SetupConnectionValidator>(
  (ref) => (url, token, requiresWrite) async {
    ref.read(nightscoutConnectionVerificationProvider).clear();
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      return SetupNightscoutVerification.invalidUrl;
    }
    if (requiresWrite && token.trim().isEmpty) {
      return SetupNightscoutVerification.tokenRequired;
    }
    try {
      if (requiresWrite || token.trim().isNotEmpty) {
        await ref
            .read(nightscoutTokenValidatorProvider)
            .validate(
              url: url,
              token: token,
              requireTreatmentWrite: requiresWrite,
            );
      }
      await ref.read(nightscoutConnectionCheckProvider)(url: url, token: token);
      ref
          .read(nightscoutConnectionVerificationProvider)
          .remember(url: url, token: token);
      return requiresWrite
          ? SetupNightscoutVerification.readWriteVerified
          : SetupNightscoutVerification.readVerified;
    } on NightscoutTokenValidationException catch (error) {
      return switch (error.issue) {
        NightscoutTokenIssue.required =>
          SetupNightscoutVerification.tokenRequired,
        NightscoutTokenIssue.invalid =>
          SetupNightscoutVerification.invalidToken,
        NightscoutTokenIssue.treatmentAccess =>
          SetupNightscoutVerification.writeAccessMissing,
        NightscoutTokenIssue.unavailable =>
          SetupNightscoutVerification.unavailable,
        NightscoutTokenIssue.invalidUrl =>
          SetupNightscoutVerification.invalidUrl,
      };
    } catch (_) {
      return SetupNightscoutVerification.unavailable;
    }
  },
);
