import '../../../../core/domain/model/device_status.dart';
import '../models/recorded_carbs_suggestion.dart';

class SelectRecordedCarbsSuggestionUseCase {
  const SelectRecordedCarbsSuggestionUseCase();

  RecordedCarbsSuggestion? call(DeviceStatus? status, DateTime cutoff) {
    if (status == null ||
        !status.hasCarbsReq ||
        !status.carbsReq.isFinite ||
        status.carbsReq <= 0 ||
        status.date.isAfter(cutoff)) {
      return null;
    }
    final at = status.suggestedAt ?? status.date;
    if (at.isAfter(cutoff)) return null;
    return RecordedCarbsSuggestion(
      grams: status.carbsReq,
      at: at,
      withinMinutes: status.carbsReqWithin > 0 ? status.carbsReqWithin : null,
    );
  }
}
