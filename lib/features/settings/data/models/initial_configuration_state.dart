import '../../../../core/data_sources/config/data_source_config.dart';

class InitialConfigurationState {
  const InitialConfigurationState({
    required this.config,
    required this.nightscoutUrl,
    required this.nightscoutToken,
    required this.userName,
    this.isSaving = false,
    this.submitError,
  });

  final DataSourceConfig config;
  final String nightscoutUrl;
  final String nightscoutToken;
  final String userName;
  final bool isSaving;
  final String? submitError;

  InitialConfigurationState copyWith({
    DataSourceConfig? config,
    String? nightscoutUrl,
    String? nightscoutToken,
    String? userName,
    bool? isSaving,
    String? submitError,
    bool clearSubmitError = false,
  }) {
    return InitialConfigurationState(
      config: config ?? this.config,
      nightscoutUrl: nightscoutUrl ?? this.nightscoutUrl,
      nightscoutToken: nightscoutToken ?? this.nightscoutToken,
      userName: userName ?? this.userName,
      isSaving: isSaving ?? this.isSaving,
      submitError: clearSubmitError ? null : submitError ?? this.submitError,
    );
  }
}
