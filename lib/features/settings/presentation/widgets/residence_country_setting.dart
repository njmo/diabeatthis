import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/location/residence_country_provider.dart';
import '../../../../common/widgets/edit_name_dialog.dart';
import '../../../../core/data/provider/shared_prefs_provider.dart';

class ResidenceCountrySetting extends ConsumerWidget {
  const ResidenceCountrySetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final country = ref.watch(residenceCountryProvider);
    final value = country.asData?.value;
    Future<void> save(String? name) async {
      try {
        final prefs = await ref.read(sharedPrefsProvider.future);
        final saved = name == null
            ? await prefs.remove(residenceCountryKey)
            : await prefs.setString(residenceCountryKey, name);
        if (!saved) throw StateError('Country preference was not saved');
        ref.invalidate(residenceCountryProvider);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.lang.settingsCountrySaveError)),
          );
        }
      }
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.public_outlined),
      title: Text(context.lang.settingsResidenceCountry),
      subtitle: Text(value ?? context.lang.settingsResidenceCountryHint),
      enabled: !country.isLoading,
      trailing: value == null
          ? const Icon(Icons.edit_outlined)
          : IconButton(
              tooltip: context.lang.settingsClearResidenceCountry,
              icon: const Icon(Icons.close),
              onPressed: () => save(null),
            ),
      onTap: () async {
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
    );
  }
}
