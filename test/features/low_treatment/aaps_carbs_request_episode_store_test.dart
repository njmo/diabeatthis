import 'package:diabeatthis/features/low_treatment/data/repositories/aaps_carbs_request_episode_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferencesAapsCarbsRequestEpisodeStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = SharedPreferencesAapsCarbsRequestEpisodeStore(
      loadPreferences: SharedPreferences.getInstance,
    );
  });

  test('acknowledgement and pending cancellation survive a reload', () async {
    final requestAt = DateTime(2026, 9, 15, 12);
    await store.acceptStatus(requestAt, 8);
    await store.start('episode');
    await store.acknowledge('episode');

    final reloaded = await SharedPreferencesAapsCarbsRequestEpisodeStore(
      loadPreferences: SharedPreferences.getInstance,
    ).load();

    expect(reloaded.id, 'episode');
    expect(reloaded.acknowledged, true);
    expect(reloaded.lastAcceptedStatusAt, requestAt);
    expect(reloaded.activeCarbsReq, 8);
    expect(reloaded.notificationCancellationPending, true);
  });

  test('withdrawal keeps the watermark until cancellation succeeds', () async {
    final requestAt = DateTime(2026, 9, 15, 12);
    await store.acceptStatus(requestAt, 8);
    await store.start('episode');
    await store.clear();

    final cleared = await store.load();
    expect(cleared.id, isNull);
    expect(cleared.activeCarbsReq, isNull);
    expect(cleared.lastAcceptedStatusAt, requestAt);
    expect(cleared.notificationCancellationPending, true);

    await store.markNotificationCancelled();
    expect((await store.load()).notificationCancellationPending, false);
  });
}
