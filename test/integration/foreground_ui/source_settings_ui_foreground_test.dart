import 'package:diabeatthis/app/providers/app_event_router_provider.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/data/provider/monitor_service_enabled_provider.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_option_availability.dart';
import 'package:diabeatthis/core/data_sources/providers/source_repository_providers.dart';
import 'package:diabeatthis/core/data_sources/receiver/data_receiver_activation_controller.dart';
import 'package:diabeatthis/core/data_sources/receiver/providers/data_receiver_activation_controller_provider.dart';
import 'package:diabeatthis/features/settings/presentation/widgets/data_source_settings_section.dart';
import 'package:diabeatthis/foreground/event/external/external_event_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/foreground_ui/foreground_ui_harness.dart';
import '../../helpers/foreground_ui/source_settings_test_doubles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'source dropdown changes persist and synchronize foreground config',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(2000, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = ForegroundAppEventRouterStub();
      ForegroundUiHarness? harness;
      await tester.runAsync(() async {
        harness = await ForegroundUiHarness.create(
          meals: false,
          foregroundOverrides: [
            glucoseHistoryRepositoryProvider.overrideWith(
              (ref) async => EmptyGlucoseHistoryRepository(),
            ),
            treatmentsHistoryRepositoryProvider.overrideWith(
              (ref) async => EmptyTreatmentsHistoryRepository(),
            ),
            deviceStatusHistoryRepositoryProvider.overrideWith(
              (ref) async => EmptyDeviceStatusHistoryRepository(),
            ),
          ],
          uiOverrides: [
            dataSourceOptionAvailabilityProvider.overrideWith(
              (ref) async => const DataSourceOptionAvailability(
                aapsInstalled: true,
                xdripInstalled: true,
              ),
            ),
            glucoseHistoryRepositoryProvider.overrideWith(
              (ref) async => EmptyGlucoseHistoryRepository(),
            ),
            treatmentsHistoryRepositoryProvider.overrideWith(
              (ref) async => EmptyTreatmentsHistoryRepository(),
            ),
            deviceStatusHistoryRepositoryProvider.overrideWith(
              (ref) async => EmptyDeviceStatusHistoryRepository(),
            ),
            monitorServiceEnabledProvider.overrideWith((ref) => false),
            dataReceiverActivationControllerProvider.overrideWithValue(
              DataReceiverActivationController(
                xdripReceiverController: NoopDataReceiverController(),
                aapsReceiverController: NoopDataReceiverController(),
              ),
            ),
            appEventRouterProvider.overrideWithValue(router),
          ],
        );
        router.handler = ExternalEventHandler(harness!.runtimeContext);
      });
      final activeHarness = harness!;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: activeHarness.uiContainer,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: DataSourceSettingsSection()),
          ),
        ),
      );
      await _pumpUntilVisible(tester);

      await tester.tap(_glucoseSourceDropdown());
      await tester.pumpAndSettle();
      await tester.tap(find.text('AAPS local').last);
      await tester.pump();
      await _pumpUntil(tester, () => router.messages.isNotEmpty);
      await tester.runAsync(() async {
        final prefs = await activeHarness.uiContainer.read(
          sharedPrefsProvider.future,
        );
        expect(prefs.getString(dataSourceBgSourceKey), 'aaps');
        expect(router.messages, hasLength(1));
        final fgConfig = await activeHarness.foregroundContainer.read(
          dataSourceConfigProvider.future,
        );
        expect(fgConfig.bgSource, BgSource.aaps);
      });
      await _pumpUntil(
        tester,
        () => find.byType(SwitchListTile).evaluate().isNotEmpty,
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      await _pumpUntil(tester, () => router.messages.length == 2);
      await tester.runAsync(() async {
        final prefs = await activeHarness.uiContainer.read(
          sharedPrefsProvider.future,
        );
        expect(prefs.getBool(dataSourceMirrorToLocalKey), isTrue);
        expect(router.messages, hasLength(2));
        final fgConfig = await activeHarness.foregroundContainer.read(
          dataSourceConfigProvider.future,
        );
        expect(fgConfig.mirrorToLocal, isTrue);
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(activeHarness.close);
    },
  );

  testWidgets('uninstalled external source is unavailable from the UI', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(2000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = ForegroundAppEventRouterStub();
    ForegroundUiHarness? harness;
    await tester.runAsync(() async {
      harness = await ForegroundUiHarness.create(
        meals: false,
        uiOverrides: [
          dataSourceOptionAvailabilityProvider.overrideWith(
            (ref) async => const DataSourceOptionAvailability.none(),
          ),
          monitorServiceEnabledProvider.overrideWith((ref) => false),
          dataReceiverActivationControllerProvider.overrideWithValue(
            DataReceiverActivationController(
              xdripReceiverController: NoopDataReceiverController(),
              aapsReceiverController: NoopDataReceiverController(),
            ),
          ),
          appEventRouterProvider.overrideWithValue(router),
        ],
      );
      router.handler = ExternalEventHandler(harness!.runtimeContext);
    });
    final activeHarness = harness!;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: activeHarness.uiContainer,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: DataSourceSettingsSection()),
        ),
      ),
    );
    await _pumpUntilVisible(tester);
    await tester.tap(_glucoseSourceDropdown());
    await tester.pumpAndSettle();
    expect(find.text('AAPS local'), findsNothing);
    expect(find.text('xDrip+ local'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(activeHarness.close);
  });

  testWidgets(
    'narrow layout keeps the history dropdown inside its available width',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dataSourceConfigProvider.overrideWith(
              (ref) async => const DataSourceConfig.defaults(),
            ),
            dataSourceOptionAvailabilityProvider.overrideWith(
              (ref) async => const DataSourceOptionAvailability.none(),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: DataSourceSettingsSection()),
          ),
        ),
      );
      await _pumpUntilVisible(tester);
      // This currently overflows the HistorySource dropdown at default width.
      // Keep the intended no-overflow regression visible while the layout bug
      // remains known, without hiding the issue from test runs.
      expect(tester.takeException(), isNull);
    },
  );
}

Finder _glucoseSourceDropdown() => find.byWidgetPredicate(
  (widget) => widget is DropdownButtonFormField<BgSource>,
);

Future<void> _pumpUntilVisible(WidgetTester tester) async =>
    _pumpUntil(tester, () => _glucoseSourceDropdown().evaluate().isNotEmpty);

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 40 && !condition(); attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(condition(), isTrue);
}
