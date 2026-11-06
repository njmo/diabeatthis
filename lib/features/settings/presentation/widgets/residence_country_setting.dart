import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/location/residence_country_provider.dart';
import '../../../../common/location/residence_country_settings_controller.dart';
import '../../../../common/widgets/edit_name_dialog.dart';
import 'settings_section_card.dart';

class ResidenceCountrySetting extends ConsumerWidget {
  const ResidenceCountrySetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final country = ref.watch(residenceCountryProvider);
    final override = ref.watch(residenceCountryOverrideProvider).asData?.value;
    final value = country.asData?.value;
    Future<void> save(String? name) async {
      try {
        await ref.read(residenceCountrySettingsControllerProvider).save(name);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.lang.settingsCountrySaveError)),
          );
        }
      }
    }

    return SettingsSectionCard(
      icon: Icons.public_outlined,
      title: context.lang.settingsResidenceCountry,
      subtitle: context.lang.settingsCountryRegionDescription,
      trailing: OutlinedButton(
        onPressed: country.isLoading
            ? null
            : () async {
                final name = await showDialog<String>(
                  context: context,
                  builder: (_) => EditNameDialog(
                    initialName: value ?? '',
                    title: context.lang.settingsResidenceCountry,
                    label: context.lang.settingsResidenceCountry,
                    requiredMessage: context.lang.settingsCountryRequired,
                  ),
                );
                if (name != null && context.mounted) await save(name);
              },
        child: Text(context.lang.settingsCountryChange),
      ),
      children: [
        if (country.isLoading)
          const LinearProgressIndicator()
        else if (country.hasError)
          Text(context.lang.settingsCountrySaveError)
        else
          Text(
            override != null
                ? context.lang.settingsCountryManual(value ?? '')
                : value != null
                ? context.lang.settingsCountryAutomatic(value)
                : context.lang.settingsCountryUnknown,
          ),
        if (override != null)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: () => save(null),
              icon: const Icon(Icons.settings_backup_restore),
              label: Text(context.lang.settingsCountryUseSystem),
            ),
          ),
      ],
    );
  }
}
