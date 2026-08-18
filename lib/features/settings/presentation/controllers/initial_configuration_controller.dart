import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../common/l10n/application_language.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/notifier_provider/simple_provider.dart';
import '../../../../common/platform/external_app_installation_checker.dart';
import '../../../../core/data_sources/config/data_source_config.dart';
import '../../../../core/data_sources/config/data_source_config_provider.dart';
import '../../../../core/data_sources/config/data_source_option_availability.dart';
import '../../../../core/data_sources/nightscout/providers/nightscout_url_provider.dart';
import '../../../../core/logger/logger.dart';
import '../../application/apply_initial_configuration_use_case.dart';
import '../../data/models/initial_configuration_state.dart';

part 'initial_configuration_controller.g.dart';

@riverpod
class InitialConfigurationController extends _$InitialConfigurationController
    with Logging {
  late ApplyInitialConfigurationUseCase _applyInitialConfigurationUseCase;

  @override
  Future<InitialConfigurationState> build() async {
    _applyInitialConfigurationUseCase = ref.watch(
      applyInitialConfigurationUseCaseProvider,
    );
    final config = await ref.read(dataSourceConfigProvider.future);
    final language = await ref.read(
      applicationLanguageControllerProvider.future,
    );
    final nightscoutUrl = await ref.read(nightscoutUrlProvider.future);
    final nightscoutToken = await ref.read(nightscoutTokenProvider.future);
    final userName = await ref.read(nameProvider.future);

    return InitialConfigurationState(
      config: config,
      language: language,
      nightscoutUrl: nightscoutUrl,
      nightscoutToken: nightscoutToken,
      userName: userName,
    );
  }

  InitialConfigurationState? get _currentState {
    return state.maybeWhen(data: (value) => value, orElse: () => null);
  }

  void setDataSourceConfig(DataSourceConfig config) {
    _update((previous) {
      if (previous.config == config) return previous;

      return previous.copyWith(config: config, clearSubmitError: true);
    });
  }

  void setUserName(String value) {
    _update((previous) {
      return previous.copyWith(userName: value, clearSubmitError: true);
    });
  }

  void setLanguage(ApplicationLanguage value) {
    _update((previous) {
      return previous.copyWith(language: value, clearSubmitError: true);
    });
  }

  void setNightscoutUrl(String value) {
    _update((previous) {
      return previous.copyWith(nightscoutUrl: value, clearSubmitError: true);
    });
  }

  void setNightscoutToken(String value) {
    _update((previous) {
      return previous.copyWith(nightscoutToken: value, clearSubmitError: true);
    });
  }

  Future<bool> submit({String? nightscoutUrl, String? nightscoutToken}) async {
    final current = _currentState;
    if (current == null || current.isSaving) return false;

    _setSaving();

    try {
      await _applyInitialConfigurationUseCase(
        config: current.config,
        nightscoutUrl: (nightscoutUrl ?? current.nightscoutUrl).trim(),
        nightscoutToken: (nightscoutToken ?? current.nightscoutToken).trim(),
        childName: current.userName.trim(),
        language: current.language,
      );
      return true;
    } on DataSourceConfigUnavailableException catch (e, st) {
      logE(
        'Initial configuration source unavailable',
        error: e,
        stackTrace: st,
      );
      _setSubmitError(_unavailableSourceMessage(e));
      return false;
    } catch (e, st) {
      logE('Initial configuration failed', error: e, stackTrace: st);
      _setSubmitError(
        current.config.usesCloud
            ? lang.settingsConnectionError
            : lang.settingsInitialSaveError,
      );
      return false;
    }
  }

  String _unavailableSourceMessage(DataSourceConfigUnavailableException error) {
    final appNames = error.missingApps.map(_externalDataAppName).join(', ');
    return lang.settingsMissingAppsSaveError(appNames);
  }

  String _externalDataAppName(ExternalDataApp app) {
    return switch (app) {
      ExternalDataApp.aaps => 'AAPS',
      ExternalDataApp.xdrip => 'xDrip+',
    };
  }

  void _setSaving() {
    _update((previous) {
      return previous.copyWith(isSaving: true, clearSubmitError: true);
    });
  }

  void _setSubmitError(String message) {
    _update((previous) {
      return previous.copyWith(isSaving: false, submitError: message);
    });
  }

  void _update(
    InitialConfigurationState Function(InitialConfigurationState previous)
    mapper,
  ) {
    final previous = _currentState;
    if (previous == null) return;

    state = AsyncData(mapper(previous));
  }
}
