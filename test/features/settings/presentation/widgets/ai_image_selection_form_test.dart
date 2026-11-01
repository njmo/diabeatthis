import 'package:diabeatthis/common/ai/ai_provider_kind.dart';
import 'package:diabeatthis/features/settings/presentation/widgets/ai_image_provider_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ai_settings_section_test.dart'
    show RecordingAiSettingsController, pumpAiSettings;

void main() {
  testWidgets(
    'image provider uses its own selection and shares the saved API key',
    (tester) async {
      final controller = RecordingAiSettingsController();
      await pumpAiSettings(tester, controller);
      final selector = find.byType(DropdownButton<AiImageProviderChoice>);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OpenAI — własny klucz API').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Klucz API OpenAI'),
        'image-api-key',
      );
      await tester.ensureVisible(find.text('Zapisz ustawienia AI'));
      await tester.tap(find.text('Zapisz ustawienia AI'));
      await tester.pumpAndSettle();
      expect(
        controller.saves.single.configuration.provider,
        AiProviderKind.firebase,
      );
      expect(
        controller.saves.single.configuration.imageProvider,
        AiProviderKind.openAi,
      );
      expect(controller.saves.single.apiKey, 'image-api-key');
      await tester.ensureVisible(selector);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ten sam co do analiz').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Zapisz ustawienia AI'));
      await tester.tap(find.text('Zapisz ustawienia AI'));
      await tester.pumpAndSettle();
      expect(controller.saves.last.configuration.imageProvider, isNull);
    },
  );
}
