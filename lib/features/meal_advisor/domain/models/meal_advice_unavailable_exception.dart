import '../../../../common/l10n/language.dart';

class MealAdviceUnavailableException implements Exception {
  const MealAdviceUnavailableException();

  @override
  String toString() => lang.uiNoCurrentCGMReadingsOrCompleteIOBCOBData;
}
