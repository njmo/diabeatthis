import 'package:auto_route/auto_route.dart';
import 'package:diabeatthis/app/app.dart';
import 'package:diabeatthis/app/providers/app_foreground_bridge_provider.dart';
import 'package:diabeatthis/app/router/app_router.dart';
import 'package:diabeatthis/app/router/guards/initial_configuration_guard.dart';
import 'package:diabeatthis/app/router/providers/app_router_provider.dart';
import 'package:diabeatthis/common/location/residence_country_provider.dart';
import 'package:diabeatthis/common/theme/application_theme_data.dart';
import 'package:diabeatthis/core/data/provider/monitor_service_enabled_provider.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/base/notifications_controller.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/regression/controlled_app_foreground_bridge.dart';

class StartupPermissionBridge extends ControlledAppForegroundBridge {
  @override
  Future<void> init() async {
    calls.add('init');
  }

  @override
  void attach(void Function(Object data) onData) {
    calls.add('attach');
  }

  @override
  void detach(void Function(Object data) onData) {
    calls.add('detach');
  }
}

class StartupNotifications implements NotificationsController {
  StartupNotifications({this.failInitialization = false});

  final bool failInitialization;
  int initializations = 0;
  @override
  Future<void> init() async {
    initializations++;
    if (failInitialization) {
      throw PlatformException(code: 'invalid_icon');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected notification action');
}

class StartupPermissionRouter extends AppRouter {
  StartupPermissionRouter(super.guard);
  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      page: PageInfo(
        'Startup',
        builder: (_) => const Scaffold(body: Text('Startup')),
      ),
      path: '/',
      initial: true,
    ),
  ];
}

void main() {
  for (final failInitialization in [false, true]) {
    testWidgets(
      'MyApp starts the foreground bridge and refreshes the locale with '
      'notification initialization failure=$failInitialization',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final bridge = StartupPermissionBridge();
        final notifications = StartupNotifications(
          failInitialization: failInitialization,
        );
        final database = DatabaseImpl(NativeDatabase.memory());
        addTearDown(database.close);
        var locales = [const Locale('en', 'GB')];
        final requests = <String>[];
        const permissionChannel = MethodChannel(
          'flutter.baseflow.com/permissions/methods',
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          permissionChannel,
          (call) async {
            requests.add(call.method);
            return <int, int>{};
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            permissionChannel,
            null,
          ),
        );
        final container = ProviderContainer(
          overrides: [
            sharedPrefsProvider.overrideWith((ref) async => prefs),
            appForegroundBridgeProvider.overrideWithValue(bridge),
            notificationsControllerUiProvider.overrideWithValue(notifications),
            monitorServiceEnabledProvider.overrideWith((ref) => false),
            databaseProvider.overrideWithValue(database),
            appRouterProvider.overrideWith(
              (ref) => StartupPermissionRouter(InitialConfigurationGuard(ref)),
            ),
            applicationLightThemeProvider.overrideWithValue(ThemeData()),
            applicationDarkThemeProvider.overrideWithValue(ThemeData.dark()),
            deviceCountryLocalesProvider.overrideWith((ref) => locales),
          ],
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: const MyApp()),
        );
        await tester.pumpAndSettle();
        expect(find.text('Startup'), findsOneWidget);
        expect(requests, isEmpty);
        expect(notifications.initializations, 1);
        expect(bridge.calls, contains('init'));
        expect(await container.read(residenceCountryProvider.future), 'GB');
        final observer =
            tester.state(find.byType(MyApp)) as WidgetsBindingObserver;
        locales = [const Locale('pl', 'PL')];
        observer.didChangeLocales(locales);
        await tester.pumpAndSettle();
        expect(await container.read(residenceCountryProvider.future), 'PL');
        await prefs.setString(residenceCountryKey, 'Portugal');
        container.invalidate(residenceCountryOverrideProvider);
        expect(
          await container.read(residenceCountryProvider.future),
          'Portugal',
        );
        locales = [const Locale('en', 'US')];
        observer.didChangeLocales(locales);
        await tester.pumpAndSettle();
        expect(
          await container.read(residenceCountryProvider.future),
          'Portugal',
        );
        expect(requests, isEmpty);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
