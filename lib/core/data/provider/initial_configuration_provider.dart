import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'shared_prefs_provider.dart';

part 'initial_configuration_provider.g.dart';

const initialConfigurationDoneKey = 'initial-configuration-done';

@Riverpod(keepAlive: true)
Future<bool> initialConfigurationDone(Ref ref) async {
  final prefs = await ref.watch(sharedPrefsProvider.future);
  return prefs.getBool(initialConfigurationDoneKey) ?? false;
}
