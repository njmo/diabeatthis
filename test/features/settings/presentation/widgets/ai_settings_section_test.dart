import 'dart:async';

import 'package:diabeatthis/common/ai/ai_configuration.dart';
import 'package:diabeatthis/common/ai/ai_model_option.dart';
import 'package:diabeatthis/common/ai/ai_provider_kind.dart';
import 'package:diabeatthis/common/ai/ai_settings_controller.dart';
import 'package:diabeatthis/common/ai/auth/chat_gpt_auth_exception.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/features/settings/presentation/widgets/ai_settings_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  testWidgets('Firebase does not read API or ChatGPT credentials', (
    tester,
  ) async {
    final controller = RecordingAiSettingsController();
    await pumpAiSettings(tester, controller);

    expect(controller.apiKeyReadCount, 0);
    expect(controller.chatGptReadCount, 0);
    expect(find.text('gemini-2.5-flash'), findsOneWidget);
  });

  testWidgets(
    'test uses unsaved provider fields and disables actions until complete',
    (tester) async {
      final controller = RecordingAiSettingsController()
        ..pendingTest = Completer<void>();
      await pumpAiSettings(tester, controller);
      await selectAiProvider(tester, 'OpenAI — własny klucz API');
      await tester.enterText(
        find.widgetWithText(TextField, 'Klucz API OpenAI'),
        'draft-key',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Model AI'),
        'draft-model',
      );
      await tester.tap(find.text('Testuj połączenie AI'));
      await tester.pump();

      expect(
        controller.tests.single.configuration.provider,
        AiProviderKind.openAi,
      );
      expect(controller.tests.single.configuration.model, 'draft-model');
      expect(controller.tests.single.apiKey, 'draft-key');
      expect(controller.saves, isEmpty);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Zapisz ustawienia AI'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<DropdownButton<AiProviderKind>>(
              find.byType(DropdownButton<AiProviderKind>),
            )
            .onChanged,
        isNull,
      );
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Klucz API OpenAI'),
            )
            .enabled,
        isFalse,
      );

      controller.pendingTest!.complete();
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Połączenie działa. Model odpowiedział na zapytanie testowe.',
        ),
        findsOneWidget,
      );
      expect(controller.saves, isEmpty);
      await tester.enterText(
        find.widgetWithText(TextField, 'Model AI'),
        'another-model',
      );
      await tester.pump();
      expect(
        find.text(
          'Połączenie działa. Model odpowiedział na zapytanie testowe.',
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'AI validation does not participate in the surrounding settings form',
    (tester) async {
      final controller = RecordingAiSettingsController();
      final parentForm = GlobalKey<FormState>();
      await pumpAiSettings(tester, controller, parentFormKey: parentForm);
      expect(find.byType(Form), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Model AI'), '');

      expect(parentForm.currentState!.validate(), isTrue);
      await tester.tap(find.text('Zapisz ustawienia AI'));
      await tester.pumpAndSettle();
      expect(find.text('Wpisz nazwę modelu.'), findsOneWidget);
      expect(controller.saves, isEmpty);
    },
  );

  testWidgets(
    'settings reload preserves unsaved provider fields and a pending test',
    (tester) async {
      final controller = RecordingAiSettingsController()
        ..pendingTest = Completer<void>();
      await pumpAiSettings(tester, controller);
      await selectAiProvider(tester, 'OpenAI — własny klucz API');
      await tester.enterText(
        find.widgetWithText(TextField, 'Klucz API OpenAI'),
        'unsaved-key',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Model AI'),
        'unsaved-model',
      );
      await tester.tap(find.text('Testuj połączenie AI'));
      await tester.pump();

      controller.beginReload();
      await tester.pump();
      expect(
        find.widgetWithText(TextField, 'Klucz API OpenAI'),
        findsOneWidget,
      );
      controller.completeReload();
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Klucz API OpenAI'),
            )
            .controller!
            .text,
        'unsaved-key',
      );
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Model AI'))
            .controller!
            .text,
        'unsaved-model',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Zapisz ustawienia AI'),
            )
            .onPressed,
        isNull,
      );
      expect(controller.saves, isEmpty);

      controller.pendingTest!.complete();
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Połączenie działa. Model odpowiedział na zapytanie testowe.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'saved API key stays concealed and can be kept or removed explicitly',
    (tester) async {
      final controller = RecordingAiSettingsController()
        ..configuration = const AiConfiguration(provider: AiProviderKind.openAi)
        ..hasSavedApiKey = true;
      await pumpAiSettings(tester, controller);

      final keyField = find.widgetWithText(TextField, 'Klucz API OpenAI');
      expect(tester.widget<TextField>(keyField).controller!.text, isEmpty);
      expect(find.textContaining('Klucz jest zapisany.'), findsOneWidget);
      await tester.tap(find.text('Zapisz ustawienia AI'));
      await tester.pumpAndSettle();
      expect(controller.saves.single.apiKey, isEmpty);

      await tester.tap(find.text('Usuń zapisany klucz'));
      await tester.pumpAndSettle();
      expect(controller.keyRemovals, 1);
      expect(find.text('Usuń zapisany klucz'), findsNothing);
      await tester.tap(find.text('Testuj połączenie AI'));
      await tester.pumpAndSettle();
      expect(find.text('Wpisz klucz API OpenAI.'), findsOneWidget);
      expect(controller.tests, isEmpty);
    },
  );

  testWidgets(
    'request errors are localized and never expose raw response details',
    (tester) async {
      final controller = RecordingAiSettingsController()
        ..testFailure = const LlmRequestException(
          failure: LlmRequestFailure.unauthorized,
          message: 'raw secret response',
        );
      await pumpAiSettings(tester, controller);
      await tester.tap(find.text('Testuj połączenie AI'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Usługa AI odmówiła dostępu. Sprawdź konfigurację dostępu do AI.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('raw secret'), findsNothing);
      expect(controller.saves, isEmpty);
    },
  );

  testWidgets(
    'ChatGPT sign-in loads account models without saving the provider',
    (tester) async {
      final controller = RecordingAiSettingsController();
      await pumpAiSettings(tester, controller);
      await selectAiProvider(tester, 'ChatGPT — własna subskrypcja');

      expect(find.text('Konto ChatGPT nie jest połączone.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Zapisz ustawienia AI'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Kontynuuj z ChatGPT'));
      await tester.pumpAndSettle();
      expect(controller.signIns, 1);
      expect(find.text('Account model A'), findsOneWidget);
      expect(controller.saves, isEmpty);

      await tester.tap(find.text('Zapisz ustawienia AI'));
      await tester.pumpAndSettle();
      expect(
        controller.saves.single.configuration.provider,
        AiProviderKind.chatGpt,
      );
      expect(
        controller.saves.single.configuration.chatGptModel,
        'account-model-a',
      );
    },
  );

  testWidgets(
    'an unavailable saved ChatGPT model requires an explicit replacement',
    (tester) async {
      final controller = RecordingAiSettingsController()
        ..configuration = const AiConfiguration(
          provider: AiProviderKind.chatGpt,
          chatGptModel: 'retired-model',
        )
        ..connected = true;
      await pumpAiSettings(tester, controller);

      expect(
        find.text('Wybierz model dostępny na tym koncie.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Zapisz ustawienia AI'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Account model B').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zapisz ustawienia AI'));
      await tester.pumpAndSettle();

      expect(
        controller.saves.single.configuration.chatGptModel,
        'account-model-b',
      );
    },
  );

  testWidgets(
    'failed ChatGPT renewal updates connection state and offers sign-in',
    (tester) async {
      final controller = RecordingAiSettingsController()
        ..configuration = const AiConfiguration(
          provider: AiProviderKind.chatGpt,
        )
        ..connected = true
        ..modelLookupClearsSession = true;
      await pumpAiSettings(tester, controller);

      expect(find.text('Kontynuuj z ChatGPT'), findsOneWidget);
      expect(find.text('Konto ChatGPT jest połączone.'), findsNothing);
      expect(
        find.text(
          'Usługa AI odmówiła dostępu. Sprawdź konfigurację dostępu do AI.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Zapisz ustawienia AI'),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'unconfirmed revocation shows local disconnect and allows signing in again',
    (tester) async {
      final controller = RecordingAiSettingsController()
        ..configuration = const AiConfiguration(
          provider: AiProviderKind.chatGpt,
        )
        ..connected = true
        ..disconnectFailure = const ChatGptRevocationUnconfirmedException();
      await pumpAiSettings(tester, controller);
      await tester.tap(find.text('Odłącz ChatGPT'));
      await tester.pumpAndSettle();

      expect(find.text('Kontynuuj z ChatGPT'), findsOneWidget);
      expect(
        find.text(
          'Odłączono konto na tym urządzeniu. Aby cofnąć dostęp wszędzie, usuń aplikację w ustawieniach ChatGPT.',
        ),
        findsOneWidget,
      );
      expect(controller.connected, isFalse);
    },
  );
}

Future<void> pumpAiSettings(
  WidgetTester tester,
  RecordingAiSettingsController controller, {
  GlobalKey<FormState>? parentFormKey,
}) async {
  tester.view.physicalSize = const Size(1200, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [aiSettingsControllerProvider.overrideWith(() => controller)],
      child: localizedMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Form(key: parentFormKey, child: const AiSettingsSection()),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> selectAiProvider(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButton<AiProviderKind>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

class RecordingAiSettingsController extends AiSettingsController {
  Completer<AiConfiguration>? pendingReload;
  AiConfiguration configuration = const AiConfiguration();
  bool hasSavedApiKey = false;
  bool connected = false;
  bool modelLookupClearsSession = false;
  int apiKeyReadCount = 0;
  int chatGptReadCount = 0;
  int keyRemovals = 0;
  int signIns = 0;
  Object? testFailure;
  Object? disconnectFailure;
  Completer<void>? pendingTest;
  final saves = <({AiConfiguration configuration, String? apiKey})>[];
  final tests = <({AiConfiguration configuration, String? apiKey})>[];

  void beginReload() {
    pendingReload = Completer<AiConfiguration>();
    ref.read(aiTestReloadProvider.notifier).increment();
  }

  void completeReload() {
    pendingReload!.complete(configuration);
    pendingReload = null;
  }

  @override
  Future<AiConfiguration> build() async {
    ref.watch(aiTestReloadProvider);
    return pendingReload == null ? configuration : await pendingReload!.future;
  }

  @override
  Future<bool> hasApiKey() async {
    apiKeyReadCount++;
    return hasSavedApiKey;
  }

  @override
  Future<bool> isChatGptConnected() async {
    chatGptReadCount++;
    return connected;
  }

  @override
  Future<void> save(AiConfiguration configuration, {String? apiKey}) async {
    saves.add((configuration: configuration, apiKey: apiKey));
    this.configuration = configuration;
    if (apiKey?.isNotEmpty ?? false) hasSavedApiKey = true;
    state = AsyncData(configuration);
  }

  @override
  Future<void> testConnection(
    AiConfiguration configuration, {
    String? apiKey,
  }) async {
    tests.add((configuration: configuration, apiKey: apiKey));
    if (testFailure case final Object failure) throw failure;
    await pendingTest?.future;
  }

  @override
  Future<void> deleteApiKey() async {
    keyRemovals++;
    hasSavedApiKey = false;
  }

  @override
  Future<void> connectChatGpt() async {
    signIns++;
    connected = true;
  }

  @override
  Future<void> disconnectChatGpt() async {
    connected = false;
    if (disconnectFailure case final Object failure) throw failure;
  }

  @override
  Future<List<AiModelOption>> chatGptModels() async {
    if (modelLookupClearsSession) {
      connected = false;
      throw const LlmRequestException(
        failure: LlmRequestFailure.unauthorized,
        message: 'The refresh token is no longer valid.',
      );
    }
    return const [
      AiModelOption(id: 'account-model-a', label: 'Account model A'),
      AiModelOption(id: 'account-model-b', label: 'Account model B'),
    ];
  }
}

final aiTestReloadProvider = NotifierProvider<AiTestReload, int>(
  AiTestReload.new,
);

class AiTestReload extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}
