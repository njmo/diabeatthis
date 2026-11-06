import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/common/l10n/application_language_picker.dart';
import 'package:diabeatthis/common/setup/domain/setup_step.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_option_availability.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';
import '../../../helpers/regression/setup_live_services.dart';

void main() {
  for (final locales in [
    const [Locale('pl', 'PL')],
    const [Locale('en', 'US')],
    const [Locale('de'), Locale('pl')],
    const [Locale('de'), Locale('fr')],
  ]) {
    testWidgets('start language follows device preferences $locales', (
      tester,
    ) async {
      tester.binding.platformDispatcher.localesTestValue = locales;
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      final polish = locales.any((locale) => locale.languageCode == 'pl');
      final auth = SetupGoogleAuthenticationTestRepository();
      addTearDown(auth.dispose);
      final draft = SetupWizardState(
        config: const DataSourceConfig.defaults(),
        language: applicationLanguageByCode(null),
        name: '',
        nightscoutUrl: '',
        nightscoutToken: '',
      );
      await tester.pumpWidget(
        localizedMaterialApp(
          home: SetupWizard(
            initialState: draft,
            availability: const DataSourceOptionAvailability.none(),
            authentication: auth,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(polish ? 'Witaj w DiaBeatThis' : 'Welcome to DiaBeatThis'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.language), findsOneWidget);
      expect(find.byType(ApplicationLanguagePicker), findsNothing);
      await tester.tap(find.byIcon(Icons.language));
      await tester.pumpAndSettle();
      final picker = find.byType(ApplicationLanguagePicker);
      expect(picker, findsOneWidget);
      expect(
        find.descendant(of: picker, matching: find.byType(ListTile)),
        findsNWidgets(2),
      );
      expect(
        find.descendant(
          of: picker,
          matching: find.text(polish ? 'Systemowy' : 'System'),
        ),
        findsNothing,
      );
      final selected = tester
          .widgetList<ListTile>(
            find.descendant(of: picker, matching: find.byType(ListTile)),
          )
          .singleWhere((tile) => tile.selected);
      expect((selected.title! as Text).data, polish ? 'Polski' : 'English');
      expect(
        draft.language.code,
        'system',
        reason:
            'Automatic resolution must not persist an explicit English or Polish preference',
      );
      expect(draft.currentStep, SetupStep.start);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('language picker follows the session locale when reopened', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localesTestValue = const [Locale('pl')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    final draft = SetupWizardState(
      config: const DataSourceConfig.defaults(),
      language: applicationLanguageByCode('en'),
      name: '',
      nightscoutUrl: '',
      nightscoutToken: '',
    );
    await tester.pumpWidget(
      localizedMaterialApp(
        home: SetupWizard(
          initialState: draft,
          availability: const DataSourceOptionAvailability.none(),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.language));
    await tester.pumpAndSettle();
    expect(find.text('App language'), findsOneWidget);
    expect(find.text('Język aplikacji'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
