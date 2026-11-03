import '../domain/models/aaps_carbs_request_episode.dart';

class IsLowTreatmentSuggestionVisibleUseCase {
  const IsLowTreatmentSuggestionVisibleUseCase();

  bool call({
    required DateTime suggestionAt,
    required AapsCarbsRequestEpisode episode,
  }) => !(episode.acknowledged && episode.matchesSuggestionAt(suggestionAt));
}
