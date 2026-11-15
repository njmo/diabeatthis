import 'dart:async';

import 'package:diabeatthis/common/ai/ai_configuration.dart';
import 'package:diabeatthis/common/ai/ai_model_option.dart';
import 'package:diabeatthis/common/ai/ai_provider_kind.dart';
import 'package:diabeatthis/common/ai/ai_settings_controller.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/common/setup/domain/setup_step.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_option_availability.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_controller.dart';
import 'package:diabeatthis/features/settings/presentation/setup/widgets/setup_wizard_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';
import 'setup_account_choice_test.dart' show accountChoiceDraft;

class AutomaticSetupAiController extends AiSettingsController {
  final calls = <String>[];
  bool failTest = false;
  bool connected = false;
  Completer<void>? login;
  @override
  Future<AiConfiguration> build() async => const AiConfiguration();
  @override
  Future<bool> hasApiKey() async => false;
  @override
  Future<bool> isChatGptConnected() async => connected;
  @override
  Future<void> connectChatGpt() async {
    calls.add('connect');
    await login?.future;
    connected = true;
  }

  @override
  Future<List<AiModelOption>> chatGptModels() async => const [
    AiModelOption(id: 'account-model', label: 'Account model'),
  ];
  @override
  Future<void> testConnection(
    AiConfiguration configuration, {
    String? apiKey,
  }) async {
    calls.add('test');
    if (failTest) throw StateError('Test rejected');
  }

  @override
  Future<void> save(AiConfiguration configuration, {String? apiKey}) async {
    calls.add('save');
    state = AsyncData(configuration);
  }
}

Finder nextAiButton() => find.descendant(
  of: find.byType(SetupWizardActions),
  matching: find.byWidgetPredicate((widget) => widget is FilledButton),
);

void main() {
  for (final failTest in [false, true]) {
    testWidgets(
      'Next tests AI before saving and advancing: failure=$failTest',
      (tester) async {
        final ai = AutomaticSetupAiController()..failTest = failTest;
        final draft = accountChoiceDraft()
          ..step = SetupStep.configuration.index
          ..nightscoutUrl = 'https://example.com'
          ..configured.add(SetupModule.nightscout);
        final modules = SetupWizardController(draft);
        draft.moduleIndex = modules.modules.indexOf(SetupModule.ai);
        modules.dispose();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [aiSettingsControllerProvider.overrideWith(() => ai)],
            child: localizedMaterialApp(
              home: SetupWizard(
                initialState: draft,
                availability: const DataSourceOptionAvailability.none(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Zapisz ustawienia AI'), findsNothing);
        expect(find.text('Model AI'), findsNothing);
        expect(
          find.textContaining('koszty pokrywa autor aplikacji'),
          findsOneWidget,
        );
        final index = draft.moduleIndex;
        await tester.tap(nextAiButton());
        await tester.pumpAndSettle();
        expect(ai.calls, failTest ? ['test'] : ['test', 'save']);
        expect(draft.currentStep, failTest ? SetupStep.configuration : SetupStep.summary);
        expect(draft.moduleIndex, index);
        expect(draft.configured.contains(SetupModule.ai), !failTest);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'selecting ChatGPT starts sign-in and blocks Next until verified',
    (tester) async {
      final ai = AutomaticSetupAiController()..login = Completer<void>();
      final draft = accountChoiceDraft()
        ..step = SetupStep.configuration.index
        ..nightscoutUrl = 'https://example.com'
        ..configured.add(SetupModule.nightscout);
      final modules = SetupWizardController(draft);
      draft.moduleIndex = modules.modules.indexOf(SetupModule.ai);
      modules.dispose();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [aiSettingsControllerProvider.overrideWith(() => ai)],
          child: localizedMaterialApp(
            home: SetupWizard(
              initialState: draft,
              availability: const DataSourceOptionAvailability.none(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .widget<DropdownButton<AiProviderKind>>(
            find.byType(DropdownButton<AiProviderKind>),
          )
          .onChanged!(AiProviderKind.chatGpt);
      await tester.pump();
      await tester.pump();
      expect(ai.calls, ['connect']);
      expect(tester.widget<FilledButton>(nextAiButton()).onPressed, isNull);
      ai.login!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Zweryfikowano konto ChatGPT'), findsOneWidget);
      expect(tester.widget<FilledButton>(nextAiButton()).onPressed, isNotNull);
      await tester.tap(nextAiButton());
      await tester.pumpAndSettle();
      expect(ai.calls, ['connect', 'test', 'save']);
      expect(tester.takeException(), isNull);
    },
  );
}
