import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_event_router_provider.dart';
import '../../../app/providers/app_foreground_bridge_provider.dart';
import '../../../app/providers/foreground_task_state_provider.dart';
import '../../../common/events/data/app/execute_command_event.dart';
import '../../../common/events/data/app/sync_data_key.dart';
import '../../../common/identifiers/create_uuid.dart';
import '../../../core/data/provider/monitor_service_enabled_provider.dart';
import '../../../core/data/provider/shared_prefs_provider.dart';
import '../../../core/data_sources/config/data_source_config_provider.dart';
import '../../../core/data_sources/nightscout/nightscout_storage_keys.dart';
import '../../../core/data_sources/nightscout/nightscout_token_validator.dart';
import '../../../core/data_sources/nightscout/providers/nightscout_connection_check_provider.dart';
import '../../../core/data_sources/nightscout/providers/nightscout_repository_provider.dart';
import '../../../core/data_sources/nightscout/providers/nightscout_url_provider.dart';
import '../../../core/logger/logger.dart';
import '../data/models/nightscout_settings_draft.dart';
import '../data/settings_storage_keys.dart';

final saveNightscoutSettingsUseCaseProvider =
    Provider<SaveNightscoutSettingsUseCase>(SaveNightscoutSettingsUseCase.new);

class SaveNightscoutSettingsUseCase with Logging {
  SaveNightscoutSettingsUseCase(this._ref);

  final Ref _ref;

  Future<void> call(NightscoutSettingsDraft draft) async {
    final prefsFuture = _ref.read(sharedPrefsProvider.future);
    final configFuture = draft.dataSourceConfig == null
        ? _ref.read(dataSourceConfigProvider.future)
        : Future.value(draft.dataSourceConfig!);
    final validator = _ref.read(nightscoutTokenValidatorProvider);
    final prefs = await prefsFuture;
    final config = await configFuture;
    if (!_ref.mounted) return;

    final url = draft.url.trim();
    final token = draft.token.trim();
    final childName = draft.childName.trim();
    final urlChanged = url != (prefs.getString(nightscoutUrlKey)?.trim() ?? '');
    final tokenChanged =
        token != (prefs.getString(nightscoutTokenKey)?.trim() ?? '');
    final childNameChanged =
        childName != (prefs.getString(childNameKey)?.trim() ?? '');
    final connectionChanged = urlChanged || tokenChanged;
    final tempTargetsChanged =
        draft.tempTargetsEnabled !=
        (prefs.getBool(nightscoutTempTargetsEnabledKey) ?? false);

    final lowTreatmentsChanged =
        draft.lowTreatmentsEnabled !=
        (prefs.getBool(nightscoutLowTreatmentsEnabledKey) ?? false);
    final requiresWrite =
        draft.tempTargetsEnabled || draft.lowTreatmentsEnabled;

    if (requiresWrite && token.isEmpty) {
      throw const NightscoutTokenValidationException(
        NightscoutTokenIssue.required,
      );
    }
    // Existing verified credentials need no network request for local edits.
    // Enabling uploads or changing credentials still validates before any write.
    final enablingTempTargets = draft.tempTargetsEnabled && tempTargetsChanged;
    if (enablingTempTargets ||
        (draft.lowTreatmentsEnabled && lowTreatmentsChanged) ||
        (connectionChanged && token.isNotEmpty)) {
      await validator.validate(
        url: url,
        token: token,
        requireTreatmentWrite: requiresWrite,
      );
    }
    if (connectionChanged && config.usesCloud) {
      await _ref.read(nightscoutConnectionCheckProvider)(
        url: url,
        token: token,
      );
    }
    if (!_ref.mounted) return;

    if (urlChanged) {
      // Rotate before changing URL: interrupted settings saves pause old deliveries.
      await prefs.setString(nightscoutDeliveryRevisionKey, createUuid());
      await prefs.setString(nightscoutUrlKey, url);
    }
    if (tokenChanged) await prefs.setString(nightscoutTokenKey, token);
    if (childNameChanged) await prefs.setString(childNameKey, childName);
    if (tempTargetsChanged) {
      await prefs.setBool(
        nightscoutTempTargetsEnabledKey,
        draft.tempTargetsEnabled,
      );
    }
    if (lowTreatmentsChanged) {
      await prefs.setBool(
        nightscoutLowTreatmentsEnabledKey,
        draft.lowTreatmentsEnabled,
      );
    }
    if (!_ref.mounted) return;

    if (connectionChanged ||
        childNameChanged ||
        tempTargetsChanged ||
        lowTreatmentsChanged) {
      _ref.invalidate(sharedPrefsProvider);
      _ref.invalidate(nightscoutRepositoryProvider);
      _ref.invalidate(nightscoutUrlProvider);
      _ref.invalidate(nightscoutTokenProvider);
    }

    if ((tempTargetsChanged || lowTreatmentsChanged) && !connectionChanged) {
      _ref
          .read(appEventRouterProvider)
          .send(
            ExecuteCommandEvent.syncSettings(
              data: {
                if (tempTargetsChanged)
                  nightscoutTempTargetsEnabledKey: draft.tempTargetsEnabled
                      .toString(),
                if (lowTreatmentsChanged)
                  nightscoutLowTreatmentsEnabledKey: draft.lowTreatmentsEnabled
                      .toString(),
              },
            ),
          );
    }

    if (connectionChanged) {
      await _restartMonitoringIfEnabled();
      if (!_ref.mounted) return;
      _ref
          .read(appEventRouterProvider)
          .send(
            const ExecuteCommandEvent.syncData(
              data: SyncDataKey.dashboardStartup,
            ),
          );
    }
  }

  Future<void> _restartMonitoringIfEnabled() async {
    if (!_ref.read(monitorServiceEnabledProvider)) return;

    final foregroundBridge = _ref.read(appForegroundBridgeProvider);
    final taskState = _ref.read(foregroundTaskStateProvider.notifier);
    try {
      final isRunning = await foregroundBridge.isServiceRunning();
      if (!_ref.mounted) return;
      taskState.setAlive(false);
      if (isRunning) {
        await foregroundBridge.restartService();
      } else {
        await foregroundBridge.startMonitoring();
      }
      if (!_ref.mounted) return;
      await taskState.waitForStartupMessage();
    } catch (error, stackTrace) {
      logW(
        'Foreground restart after Nightscout settings save failed: $error\n$stackTrace',
      );
    }
  }
}
