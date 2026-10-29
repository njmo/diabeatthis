import 'package:diabeatthis/app/providers/app_event_router_provider.dart';
import 'package:diabeatthis/core/data/provider/monitor_service_enabled_provider.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_option_availability.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_storage_keys.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_token_validator.dart';
import 'package:diabeatthis/features/settings/data/settings_storage_keys.dart';
import 'package:diabeatthis/features/settings/presentation/screens/settings_page.dart';
import 'package:diabeatthis/features/settings/presentation/widgets/temp_target_settings_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/localized_material_app.dart';
import '../../application/save_nightscout_settings_use_case_test.dart';

void main() {
  testWidgets(
    'reopening during a save retains its submitted credentials and opt-in',
    (tester) async {
      tester.view.physicalSize = const Size(2600, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        nightscoutUrlKey: 'https://previous.example.com',
        nightscoutTokenKey: 'previous-token',
        nightscoutTempTargetsEnabledKey: false,
        childNameKey: 'Before',
        dataSourceBgSourceKey: 'aaps',
        dataSourceTreatmentsSourceKey: 'aaps',
        dataSourcePumpStatusSourceKey: 'aaps',
        dataSourceHistorySourceKey: 'local',
      });
      final prefs = await SharedPreferences.getInstance();
      final validator = ControlledNightscoutTokenValidator();
      final visible = ValueNotifier(true);
      addTearDown(visible.dispose);
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWith((_) async => prefs),
          nightscoutTokenValidatorProvider.overrideWithValue(validator),
          monitorServiceEnabledProvider.overrideWith((_) => false),
          appEventRouterProvider.overrideWithValue(
            RecordingSettingsEventRouter(),
          ),
          dataSourceOptionAvailabilityProvider.overrideWith(
            (_) async => const DataSourceOptionAvailability.none(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedMaterialApp(
            home: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (_, show, _) =>
                  show ? const SettingsPage() : const SizedBox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Finder field(String label) => find.widgetWithText(TextFormField, label);
      Finder toggle() => find.descendant(
        of: find.byType(TempTargetSettingsSwitch),
        matching: find.byType(SwitchListTile),
      );
      String text(String label) =>
          tester.widget<TextFormField>(field(label)).controller!.text;

      await tester.ensureVisible(field('Nightscout URL'));
      await tester.enterText(
        field('Nightscout URL'),
        'https://saved.example.com',
      );
      await tester.enterText(field('Token Nightscout'), 'saved-token');
      await tester.enterText(field('Imię dziecka'), 'Saved');
      await tester.tap(toggle());
      await tester.pumpAndSettle();
      final save = find.text('Zapisz i przejdź dalej');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();
      await validator.started.future;

      visible.value = false;
      await tester.pump();
      visible.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(text('Nightscout URL'), 'https://saved.example.com');
      expect(text('Token Nightscout'), 'saved-token');
      expect(text('Imię dziecka'), 'Saved');
      expect(tester.widget<SwitchListTile>(toggle()).value, isTrue);
      expect(
        tester.widget<TextFormField>(field('Token Nightscout')).enabled,
        isFalse,
      );

      validator.result.complete();
      await tester.pumpAndSettle();
      expect(prefs.getString(nightscoutUrlKey), 'https://saved.example.com');
      expect(prefs.getString(nightscoutTokenKey), 'saved-token');
      expect(prefs.getBool(nightscoutTempTargetsEnabledKey), isTrue);
      expect(text('Token Nightscout'), 'saved-token');
      expect(tester.widget<SwitchListTile>(toggle()).value, isTrue);
      expect(
        tester.widget<TextFormField>(field('Token Nightscout')).enabled,
        isTrue,
      );

      // Ordinary preference refreshes must preserve edits made after that save.
      await tester.ensureVisible(field('Imię dziecka'));
      await tester.enterText(field('Imię dziecka'), 'New unsaved edit');
      await prefs.setString(childNameKey, 'External saved value');
      container.invalidate(sharedPrefsProvider);
      await tester.pumpAndSettle();
      expect(text('Imię dziecka'), 'New unsaved edit');
      expect(tester.takeException(), isNull);
    },
  );
}
