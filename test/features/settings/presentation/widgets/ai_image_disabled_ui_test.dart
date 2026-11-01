import 'package:diabeatthis/common/ai/ai_configuration.dart';
import 'package:diabeatthis/common/ai/ai_provider_kind.dart';
import 'package:diabeatthis/common/ai/ai_settings_controller.dart';
import 'package:diabeatthis/features/ingredients/presentation/widgets/ingredient_icon_picker.dart';
import 'package:diabeatthis/features/settings/presentation/widgets/ai_image_provider_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/localized_material_app.dart';

class DisabledImageSettings extends AiSettingsController {
  @override
  Future<AiConfiguration> build() async =>
      const AiConfiguration(imageGenerationEnabled: false);
}

void main() {
  testWidgets(
    'disabled generation hides the action even for a capable provider',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiSettingsControllerProvider.overrideWith(
              DisabledImageSettings.new,
            ),
          ],
          child: localizedMaterialApp(
            home: const Scaffold(body: IngredientIconPicker(name: 'Apple')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsNothing);
      expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
    },
  );
  testWidgets('ChatGPT defaults to disabled with no inheritance option', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var changes = 0;
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: AiImageProviderSelector(
              value: null,
              mainProvider: AiProviderKind.chatGpt,
              enabled: true,
              onChanged: (_) => changes++,
              onDisable: () => changes++,
            ),
          ),
        ),
      ),
    );
    final dropdown = tester.widget<DropdownButton<AiImageProviderChoice>>(
      find.byType(DropdownButton<AiImageProviderChoice>),
    );
    expect(
      dropdown.items!.any(
        (item) => item.value == AiImageProviderChoice.inherit,
      ),
      isFalse,
    );
    expect(dropdown.value, AiImageProviderChoice.disabled);
    expect(
      dropdown.items!.any(
        (item) => item.value == AiImageProviderChoice.chatGpt,
      ),
      isFalse,
    );
    await tester.tap(find.byType(DropdownButton<AiImageProviderChoice>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generowanie obrazów wyłączone').last);
    await tester.pumpAndSettle();
    expect(changes, 1);
    expect(tester.takeException(), isNull);
  });
}
