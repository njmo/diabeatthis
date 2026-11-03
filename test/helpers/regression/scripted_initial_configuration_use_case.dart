import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/features/settings/application/apply_initial_configuration_use_case.dart';

import 'scripted_read.dart';

class ScriptedInitialConfigurationUseCase
    implements ApplyInitialConfigurationUseCase {
  final ScriptedRead<void> writes;
  ScriptedInitialConfigurationUseCase(this.writes);

  @override
  Future<void> call({
    required DataSourceConfig config,
    required String nightscoutUrl,
    required String nightscoutToken,
    required String childName,
    required ApplicationLanguage language,
  }) => writes([
    config,
    nightscoutUrl,
    nightscoutToken,
    childName,
    language.code,
  ]);
}
