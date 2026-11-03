import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/is_low_treatment_suggestion_visible_use_case.dart';
import 'aaps_carbs_request_episode_store_provider.dart';

final lowTreatmentSuggestionVisibilityProvider = FutureProvider.autoDispose
    .family<bool, DateTime>((ref, at) async {
      final episode = await ref
          .watch(aapsCarbsRequestEpisodeStoreProvider)
          .load();
      return const IsLowTreatmentSuggestionVisibleUseCase()(
        suggestionAt: at,
        episode: episode,
      );
    });
