import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/provider/shared_prefs_provider.dart';
import '../repositories/aaps_carbs_request_episode_store.dart';

final aapsCarbsRequestEpisodeStoreProvider =
    Provider<AapsCarbsRequestEpisodeStore>(
      (ref) => SharedPreferencesAapsCarbsRequestEpisodeStore(
        loadPreferences: () => ref.read(sharedPrefsProvider.future),
      ),
    );
