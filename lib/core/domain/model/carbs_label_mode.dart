import '../../../common/l10n/language.dart';

enum CarbsLabelMode { eu, nonEu }

extension CarbsLabelModeX on CarbsLabelMode {
  String get label => switch (this) {
    CarbsLabelMode.eu => lang.uiEU,
    CarbsLabelMode.nonEu => lang.uiNonEU,
  };

  String get description => switch (this) {
    CarbsLabelMode.eu => lang.uiLabelCarbohydratesAreAlreadyNet,
    CarbsLabelMode.nonEu => lang.uiFiberIsSubtractedFromTotalCarbohydrates,
  };

  static CarbsLabelMode fromStorage(String? value) {
    return switch (value) {
      'eu' => CarbsLabelMode.eu,
      'non_eu' => CarbsLabelMode.nonEu,
      _ => CarbsLabelMode.nonEu,
    };
  }

  String get storageValue => switch (this) {
    CarbsLabelMode.eu => 'eu',
    CarbsLabelMode.nonEu => 'non_eu',
  };
}
