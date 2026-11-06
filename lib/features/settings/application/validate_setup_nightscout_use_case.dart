import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/setup/domain/validate_setup_module_use_case.dart';
import '../../../core/data_sources/nightscout/nightscout_connection_verification.dart';
import '../../../core/data_sources/nightscout/nightscout_token_validator.dart';
import '../../../core/data_sources/nightscout/providers/nightscout_connection_check_provider.dart';

final validateSetupNightscoutProvider = Provider<SetupConnectionValidator>(
  (ref) => (url, token, requiresWrite) async {
    ref.read(nightscoutConnectionVerificationProvider).clear();
    await ref.read(nightscoutConnectionCheckProvider)(url: url, token: token);
    if (requiresWrite || token.isNotEmpty) {
      await ref
          .read(nightscoutTokenValidatorProvider)
          .validate(
            url: url,
            token: token,
            requireTreatmentWrite: requiresWrite,
          );
    }
    ref
        .read(nightscoutConnectionVerificationProvider)
        .remember(url: url, token: token);
    return true;
  },
);
