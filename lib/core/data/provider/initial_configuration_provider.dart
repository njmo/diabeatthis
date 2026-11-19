import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shared_prefs_provider.dart';

part 'initial_configuration_provider.g.dart';

const initialConfigurationDoneKey = 'initial-configuration-done';
const initialConfigurationReceiptKey = 'initial-configuration-receipt';
typedef InitialConfigurationBinding = ({String uid, String nonce});

Map<String, dynamic>? _receipt(SharedPreferences prefs) {
  try {
    final value = jsonDecode(
      prefs.getString(initialConfigurationReceiptKey) ?? 'null',
    );
    return value is Map<String, dynamic> &&
            value['version'] == 1 &&
            value['done'] == true
        ? value
        : null;
  } catch (_) {
    return null;
  }
}

bool hasInitialConfiguration(SharedPreferences prefs) =>
    _receipt(prefs) != null ||
    prefs.getBool(initialConfigurationDoneKey) == true;

bool hasConfigurationBinding(
  SharedPreferences prefs,
  InitialConfigurationBinding binding,
) {
  final receipt = _receipt(prefs);
  return receipt?['chatBindings'] is Map &&
      receipt!['chatBindings'][binding.uid] == binding.nonce;
}

/// One durable write commits setup and its exact optional chat draft together.
Future<void> completeInitialConfiguration(
  SharedPreferences prefs, {
  InitialConfigurationBinding? binding,
}) async {
  final previous = _receipt(prefs)?['chatBindings'];
  final bindings = <String, dynamic>{
    if (previous is Map) ...Map<String, dynamic>.from(previous),
    if (binding != null) binding.uid: binding.nonce,
  };
  if (!await prefs.setString(
    initialConfigurationReceiptKey,
    jsonEncode({'version': 1, 'done': true, 'chatBindings': bindings}),
  )) {
    throw StateError('Configuration completion was not saved');
  }
  // Compatibility mirror is never the commit point for a new draft.
  try {
    await prefs.setBool(initialConfigurationDoneKey, true);
  } catch (_) {}
}

@Riverpod(keepAlive: true)
Future<bool> initialConfigurationDone(Ref ref) async {
  final prefs = await ref.watch(sharedPrefsProvider.future);
  return hasInitialConfiguration(prefs);
}
