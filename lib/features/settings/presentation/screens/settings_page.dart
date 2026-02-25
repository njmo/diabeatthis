import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/provider/shared_prefs_provider.dart';

const _nightscoutUrlKey = 'nightscout_url';
const _childNameKey = 'main-user-name';

@RoutePage()
class SettingsPage extends HookConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(sharedPrefsProvider);
    final formKey = GlobalKey<FormState>();

    return prefsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Błąd: $e'))),
      data: (prefs) {
        return Scaffold(
          appBar: AppBar(title: const Text('Quick settings')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  const Text(
                    'Podaj adres swojego Nightscout. Bez niego nie możemy pobrać danych.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: prefs.getString(_nightscoutUrlKey) ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Nightscout URL',
                      hintText: 'https://twoj-nightscout.com',
                    ),
                    keyboardType: TextInputType.url,
                    onSaved: (value) async {
                      if (value!.isEmpty) return;

                      await prefs.setString(_nightscoutUrlKey, value);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: prefs.getString(_childNameKey) ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Imie dziecka',
                      hintText: 'Oliwier',
                    ),
                    keyboardType: TextInputType.url,
                    onSaved: (value) async {
                      if (value!.isEmpty) return;

                      await prefs.setString(_childNameKey, value);
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () async {
                      formKey.currentState?.save();
                      ref.invalidate(sharedPrefsProvider);
                      context.router.pop();
                    },
                    child: const Text('Zapisz i przejdź dalej'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
