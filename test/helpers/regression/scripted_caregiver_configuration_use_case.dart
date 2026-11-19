import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/core/data/provider/initial_configuration_provider.dart';
import 'package:diabeatthis/features/settings/application/apply_caregiver_configuration_use_case.dart';

import 'scripted_read.dart';

class ScriptedCaregiverConfigurationUseCase
    extends ApplyCaregiverConfigurationUseCase {
  const ScriptedCaregiverConfigurationUseCase(super.ref, this.writes);
  final ScriptedRead<void> writes;
  @override
  Future<void> call({
    required String url,
    required String token,
    required String userName,
    required ApplicationLanguage language,
    InitialConfigurationBinding? chatSetupBinding,
  }) => writes([url, token, userName, language.code]);
}
