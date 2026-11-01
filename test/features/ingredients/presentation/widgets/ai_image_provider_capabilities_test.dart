import 'package:diabeatthis/common/ai/ai_capability_unavailable_exception.dart';
import 'package:diabeatthis/common/ai/ai_configuration.dart';
import 'package:diabeatthis/common/ai/ai_provider_capabilities.dart';
import 'package:diabeatthis/common/ai/ai_provider_kind.dart';
import 'package:diabeatthis/common/ai/ai_settings_controller.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/widgets/action_choice_card.dart';
import 'package:diabeatthis/features/ingredients/presentation/widgets/food_icon_generation_dialog.dart';
import 'package:diabeatthis/features/ingredients/presentation/widgets/ingredient_icon_error_message.dart';
import 'package:diabeatthis/features/ingredients/presentation/widgets/ingredient_icon_picker.dart';
import 'package:diabeatthis/features/settings/presentation/widgets/ai_settings_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  test(
    'image generation capabilities distinguish API keys from ChatGPT plans',
    () {
      expect(supportsAiImageGeneration(AiProviderKind.firebase), isTrue);
      expect(supportsAiImageGeneration(AiProviderKind.openAi), isTrue);
      expect(supportsAiImageGeneration(AiProviderKind.chatGpt), isFalse);
    },
  );

  for (final code in ['pl', 'en']) {
    test('unsupported image generation has a dedicated $code explanation', () {
      final language = lookupAppLocalizations(Locale(code));
      final message = ingredientIconErrorMessage(
        language,
        const AiCapabilityUnavailableException(),
      );
      expect(message, language.aiImageGenerationUnsupported);
      expect(message, isNot(language.ingredientAiUnavailable));
    });
  }

  for (final provider in AiProviderKind.values) {
    testWidgets(
      'icon generation reflects the selected ${provider.name} provider',
      (tester) async {
        final controller = ImageCapabilitySettingsController(provider);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              aiSettingsControllerProvider.overrideWith(() => controller),
            ],
            child: localizedMaterialApp(
              home: const Scaffold(body: IngredientIconPicker(name: 'Apple')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final language = lookupAppLocalizations(const Locale('pl'));
        final actionFinder = find.widgetWithText(
          ActionChoiceCard,
          language.ingredientGenerateIcon,
        );
        if (provider == AiProviderKind.chatGpt) {
          expect(actionFinder, findsNothing);
          expect(find.byType(FoodIconGenerationDialog), findsNothing);
        } else {
          expect(
            tester.widget<ActionChoiceCard>(actionFinder).onPressed,
            isNotNull,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'settings explain unavailable images for the unsaved provider choice',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ImageCapabilitySettingsController(
        AiProviderKind.firebase,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiSettingsControllerProvider.overrideWith(() => controller),
          ],
          child: localizedMaterialApp(
            home: const Scaffold(
              body: SingleChildScrollView(child: AiSettingsSection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final language = lookupAppLocalizations(const Locale('pl'));
      expect(find.text(language.settingsAiImageGenerationNote), findsOneWidget);
      expect(find.text(language.settingsAiImagesAlternative), findsNothing);

      await tester.tap(find.byType(DropdownButton<AiProviderKind>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(language.settingsAiChatGptProvider).last);
      await tester.pumpAndSettle();
      expect(find.text(language.settingsAiImagesAlternative), findsOneWidget);

      await tester.tap(find.byType(DropdownButton<AiProviderKind>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(language.settingsAiOpenAiProvider).last);
      await tester.pumpAndSettle();
      expect(find.text(language.settingsAiImagesAlternative), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AiSettingsSection)),
      );
      expect(
        container.read(aiSettingsControllerProvider).requireValue.provider,
        AiProviderKind.firebase,
      );
    },
  );
}

class ImageCapabilitySettingsController extends AiSettingsController {
  ImageCapabilitySettingsController(this.provider);

  final AiProviderKind provider;

  @override
  Future<AiConfiguration> build() async => AiConfiguration(provider: provider);

  @override
  Future<bool> hasApiKey() async => true;

  @override
  Future<bool> isChatGptConnected() async => false;
}
