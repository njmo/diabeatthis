import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/provider/shared_prefs_provider.dart';

const _nightscoutUrlKey = 'nightscout_url';

@RoutePage()
class NightscoutSetupPage extends ConsumerWidget {
  const NightscoutSetupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(sharedPrefsProvider);

    return prefsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Błąd: $e')),
      ),
      data: (prefs) {
        final controller = TextEditingController(
          text: prefs.getString(_nightscoutUrlKey) ?? '',
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Nightscout URL'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Podaj adres swojego Nightscout. Bez niego nie możemy pobrać danych.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Nightscout URL',
                    hintText: 'https://twoj-nightscout.com',
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () async {
                    final value = controller.text.trim();
                    if (value.isEmpty) return;

                    await prefs.setString(_nightscoutUrlKey, value);

                    if (context.mounted) {
                      context.router.replace(NamedRoute('DashboardRoute'));
                    }
                  },
                  child: const Text('Zapisz i przejdź dalej'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
