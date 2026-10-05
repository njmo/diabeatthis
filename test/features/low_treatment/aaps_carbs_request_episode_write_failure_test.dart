import 'dart:collection';

import 'package:diabeatthis/features/low_treatment/data/repositories/aaps_carbs_request_episode_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferencesStorePlatform originalPlatform;
  late _ControllablePreferencesPlatform platform;

  setUp(() {
    originalPlatform = SharedPreferencesStorePlatform.instance;
    platform = _ControllablePreferencesPlatform();
    SharedPreferencesStorePlatform.instance = platform;
    SharedPreferences.resetStatic();
  });

  tearDown(() {
    SharedPreferencesStorePlatform.instance = originalPlatform;
    SharedPreferences.resetStatic();
  });

  test('false platform result reloads persisted truth before retry', () async {
    final persistedAt = DateTime(2026, 9, 15, 12);
    final store = await _seed(persistedAt);
    platform.writeOutcomes.add(false);

    await expectLater(
      store.acceptStatus(persistedAt.add(const Duration(minutes: 1)), 12),
      throwsStateError,
    );

    final restored = await store.load();
    expect(restored.id, 'episode');
    expect(restored.lastAcceptedStatusAt, persistedAt);
    expect(restored.activeCarbsReq, 8);

    final retriedAt = persistedAt.add(const Duration(minutes: 1));
    await store.acceptStatus(retriedAt, 12);
    final afterRetry = await store.load();
    expect(afterRetry.lastAcceptedStatusAt, retriedAt);
    expect(afterRetry.activeCarbsReq, 12);
  });

  test('write and reload failures propagate; restart reads disk', () async {
    final persistedAt = DateTime(2026, 9, 15, 12);
    final store = await _seed(persistedAt);
    platform.writeOutcomes.add(StateError('platform write failed'));

    await expectLater(
      store.acceptStatus(persistedAt.add(const Duration(minutes: 1)), 12),
      throwsStateError,
    );

    platform.readFailure = StateError('platform reload failed');
    await expectLater(store.load(), throwsStateError);
    platform.readFailure = null;

    SharedPreferences.resetStatic();
    final restarted = SharedPreferencesAapsCarbsRequestEpisodeStore(
      loadPreferences: SharedPreferences.getInstance,
    );
    final restored = await restarted.load();
    expect(restored.id, 'episode');
    expect(restored.lastAcceptedStatusAt, persistedAt);
    expect(restored.activeCarbsReq, 8);
  });
}

Future<SharedPreferencesAapsCarbsRequestEpisodeStore> _seed(
  DateTime persistedAt,
) async {
  final store = SharedPreferencesAapsCarbsRequestEpisodeStore(
    loadPreferences: SharedPreferences.getInstance,
  );
  await store.acceptStatus(persistedAt, 8);
  await store.start('episode');
  return store;
}

class _ControllablePreferencesPlatform extends SharedPreferencesStorePlatform {
  final persisted = <String, Object>{};
  final writeOutcomes = Queue<Object>();
  Object? readFailure;

  @override
  Future<Map<String, Object>> getAll() async {
    final failure = readFailure;
    if (failure != null) throw failure;
    return Map.of(persisted);
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (writeOutcomes.isNotEmpty) {
      final outcome = writeOutcomes.removeFirst();
      if (outcome is bool && !outcome) return false;
      if (outcome is Error) throw outcome;
      if (outcome is Exception) throw outcome;
    }
    persisted[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    persisted.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    persisted.clear();
    return true;
  }
}
