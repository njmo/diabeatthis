import 'package:diabeatthis/features/meal_analysis/domain/use_cases/select_recorded_carbs_suggestion_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/device_status_factory.dart';

void main() {
  test('only an observed positive historical suggestion is shown, without inventing a deadline', () {
    final at = DateTime(2026, 11, 3, 12);
    final status = testDeviceStatus(date: at, iob: 0, cob: 0, tick: '', bg: 120).copyWith(carbsReq: 10, hasCarbsReq: true, carbsReqWithin: 0);
    const select = SelectRecordedCarbsSuggestionUseCase();
    final recorded = select(status, at)!;
    expect(recorded.grams, 10);
    expect(recorded.at, at);
    expect(recorded.withinMinutes, isNull);
    expect(select(status.copyWith(hasCarbsReq: false), at), isNull);
    expect(select(status.copyWith(carbsReq: 0), at), isNull);
    expect(select(status.copyWith(carbsReq: double.nan), at), isNull);
    expect(select(status.copyWith(suggestedAt: at.add(const Duration(minutes: 1))), at), isNull);
    expect(select(status.copyWith(date: at.add(const Duration(minutes: 1))), at), isNull);
  });
}
