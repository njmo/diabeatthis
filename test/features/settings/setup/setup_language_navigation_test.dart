import 'package:diabeatthis/common/l10n/application_language_picker.dart';
import 'package:diabeatthis/common/setup/domain/setup_step.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_option_availability.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard.dart';
import 'package:diabeatthis/features/settings/presentation/setup/widgets/setup_language_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';
import 'setup_account_choice_test.dart' show accountChoiceDraft;

void main() {
  testWidgets(
    'language action is available on every main step and opens choices directly',
    (tester) async {
      final draft = accountChoiceDraft();
      await tester.pumpWidget(
        localizedMaterialApp(
          home: SetupWizard(
            initialState: draft,
            availability: const DataSourceOptionAvailability.none(),
          ),
        ),
      );
      final wizard = tester.state<SetupWizardViewState>(
        find.byType(SetupWizard),
      );
      for (final step in SetupStep.values) {
        wizard.controller.goTo(step.index);
        await tester.pumpAndSettle();
        expect(find.byType(SetupLanguageControl), findsOneWidget);
      }
      wizard.controller.goTo(SetupStep.role.index);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.language));
      await tester.pumpAndSettle();
      final picker = find.byType(ApplicationLanguagePicker);
      expect(picker, findsOneWidget);
      expect(
        find.descendant(of: picker, matching: find.byType(ListTile)),
        findsNWidgets(2),
      );
      expect(
        find.descendant(of: picker, matching: find.text('Systemowy')),
        findsNothing,
      );
      await tester.tap(
        find.descendant(of: picker, matching: find.text('Angielski')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ApplicationLanguagePicker), findsNothing);
      expect(draft.language.code, 'en');
      expect(draft.currentStep, SetupStep.role);
      expect(find.text('Who uses this phone?'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SetupLanguageControl),
          matching: find.text('English'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
