import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/ai/ai_settings_controller.dart';
import '../../../../common/l10n/language.dart';
import 'ai_provider_settings_form.dart';
import 'settings_section_card.dart';

class AiSettingsSection extends ConsumerWidget {
  const AiSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => SettingsSectionCard(
    icon: Icons.auto_awesome_outlined,
    title: context.lang.settingsAiTitle,
    subtitle: context.lang.settingsAiSubtitle,
    children: [
      ref
          .watch(aiSettingsControllerProvider)
          .when(
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Text(context.lang.settingsAiLoadFailed),
            data: (configuration) =>
                AiProviderSettingsForm(initialConfiguration: configuration),
          ),
    ],
  );
}
