import '../model/foreground_event.dart';

class AapsCarbsRequestAcknowledgedEvent extends ForegroundEvent {
  final String? episodeId;
  final DateTime? suggestionAt;

  const AapsCarbsRequestAcknowledgedEvent({this.episodeId, this.suggestionAt});
}
