import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/provider/initial_configuration_provider.dart';
import '../../../core/data/provider/shared_prefs_provider.dart';
import '../../auth/google_authentication_providers.dart';
import '../domain/family_chat_preferences.dart';

String familyChatPreferencesKey(String uid) => 'family_chat.preferences.$uid';

final familyChatPreferencesProvider = Provider<FamilyChatPreferences>((ref) {
  final uid = ref.watch(googleAccountProvider).asData?.value?.uid;
  final prefs = ref.watch(sharedPrefsProvider).asData?.value;
  if (uid == null || prefs == null) {
    return const FamilyChatPreferences(enabled: false);
  }
  final value = FamilyChatPreferences.decode(
    prefs.getString(familyChatPreferencesKey(uid)),
  );
  return !value.setupCommitted &&
          value.changeId != null &&
          hasConfigurationBinding(prefs, (uid: uid, nonce: value.changeId!))
      ? value.committedSetup()
      : value;
});

/// Local setup/configuration draft. The server policy is introduced separately.
final saveFamilyChatPreferencesProvider = Provider(
  (ref) => (FamilyChatPreferences value, {required String expectedUid}) async {
    if (ref.read(googleAccountProvider).asData?.value?.uid != expectedUid) {
      throw StateError('Account changed');
    }
    final prefs = await ref.read(sharedPrefsProvider.future);
    if (ref.read(googleAccountProvider).asData?.value?.uid != expectedUid) {
      throw StateError('Account changed');
    }
    if (!await prefs.setString(
      familyChatPreferencesKey(expectedUid),
      value.encode(),
    )) {
      throw StateError('Chat preferences were not saved');
    }
    if (ref.mounted) ref.invalidate(familyChatPreferencesProvider);
  },
);

final configureFamilyChatPreferencesProvider = Provider(
  (ref) =>
      (
        FamilyChatPreferences? value,
        Future<bool> Function(InitialConfigurationBinding? binding) apply, {
        required String? expectedUid,
      }) async {
        if (value == null) return apply(null);
        final uid = expectedUid;
        if (uid == null ||
            ref.read(googleAccountProvider).asData?.value?.uid != uid) {
          throw StateError('Account changed');
        }
        final prefs = await ref.read(sharedPrefsProvider.future);
        final key = familyChatPreferencesKey(uid);
        final previous = prefs.getString(key);
        final pending = value.asPendingSetup();
        final binding = (uid: uid, nonce: pending.changeId!);
        await ref.read(saveFamilyChatPreferencesProvider)(
          pending,
          expectedUid: uid,
        );
        var saved = false;
        try {
          if (ref.read(googleAccountProvider).asData?.value?.uid != uid) {
            throw StateError('Account changed');
          }
          if (!await apply(binding) &&
              !hasConfigurationBinding(prefs, binding)) {
            return false;
          }
          if (!hasConfigurationBinding(prefs, binding)) {
            throw StateError('Setup completion receipt missing');
          }
          saved = true;
          if (ref.mounted) ref.invalidate(familyChatPreferencesProvider);
          return true;
        } catch (_) {
          if (!hasConfigurationBinding(prefs, binding)) rethrow;
          saved = true;
          if (ref.mounted) ref.invalidate(familyChatPreferencesProvider);
          return true;
        } finally {
          if (!saved &&
              !hasConfigurationBinding(prefs, binding) &&
              prefs.getString(key) == pending.encode()) {
            final restored = previous == null
                ? await prefs.remove(key)
                : await prefs.setString(key, previous);
            if (!restored) {
              throw StateError('Chat configuration rollback failed');
            }
            if (ref.mounted) ref.invalidate(familyChatPreferencesProvider);
          }
        }
      },
);
