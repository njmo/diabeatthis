import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../common/notifier_provider/simple_provider.dart';
import '../../../../core/data_sources/config/data_source_config.dart';
import '../../../../core/data_sources/config/data_source_config_provider.dart';
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
    final nightscoutUrl = await ref.read(nightscoutUrlProvider.future);
    final userName = await ref.read(nameProvider.future);

    return InitialConfigurationState(
      config: config,
      nightscoutUrl: nightscoutUrl,
      userName: userName,
    );
  }

  InitialConfigurationState? get _currentState {
    return state.maybeWhen(data: (value) => value, orElse: () => null);
  }

  void setDataSourceConfig(DataSourceConfig config) {
    _update((previous) {
      return previous.copyWith(config: config, clearSubmitError: true);
    });
  }

  void setUserName(String value) {
    _update((previous) {
      return previous.copyWith(userName: value, clearSubmitError: true);
    });
  }

  void setNightscoutUrl(String value) {
    _update((previous) {
      return previous.copyWith(nightscoutUrl: value, clearSubmitError: true);
    });
  }

  Future<bool> submit({String? nightscoutUrl}) async {
    final current = _currentState;
    if (current == null || current.isSaving) return false;

    _setSaving();

    try {
      await _applyInitialConfigurationUseCase(
        config: current.config,
        nightscoutUrl: (nightscoutUrl ?? current.nightscoutUrl).trim(),
        childName: current.userName.trim(),
      );
      return true;
    } catch (e, st) {
      logE('Initial configuration failed', error: e, stackTrace: st);
      _setSubmitError(
        current.config.usesCloud
            ? 'Nie udało się połączyć z Nightscout. Sprawdź adres URL.'
            : 'Nie udało się zapisać konfiguracji. Spróbuj ponownie.',
      );
      return false;
    }
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
