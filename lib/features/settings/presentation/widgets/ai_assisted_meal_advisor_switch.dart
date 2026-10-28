import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../meal_advisor/data/providers/ai_assisted_meal_advisor_settings_provider.dart';

class AiAssistedMealAdvisorSwitch extends HookConsumerWidget {
  const AiAssistedMealAdvisorSwitch({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(aiAssistedMealAdvisorEnabledProvider);
    final saving = useState(false);
    final failed = useState(false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.lang.settingsAiAssistedMealAdvisorTitle),
          subtitle: Text(context.lang.settingsAiAssistedMealAdvisorSubtitle),
          value: enabled,
          onChanged: saving.value
              ? null
              : (value) async {
                  saving.value = true;
                  failed.value = false;
                  try {
                    await ref
                        .read(aiAssistedMealAdvisorSettingsControllerProvider)
                        .save(value);
                  } catch (_) {
                    if (context.mounted) failed.value = true;
                  } finally {
                    if (context.mounted) saving.value = false;
                  }
                },
        ),
        if (failed.value)
          Text(context.lang.settingsAiAssistedMealAdvisorSaveFailed),
      ],
    );
  }
}
