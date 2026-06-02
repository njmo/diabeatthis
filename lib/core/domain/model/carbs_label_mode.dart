enum CarbsLabelMode { eu, nonEu }

extension CarbsLabelModeX on CarbsLabelMode {
  String get label => switch (this) {
    CarbsLabelMode.eu => 'UE',
    CarbsLabelMode.nonEu => 'non-UE',
  };

  String get description => switch (this) {
    CarbsLabelMode.eu => 'Węglowodany z etykiety są już netto',
    CarbsLabelMode.nonEu => 'Błonnik odejmujemy od total carbs',
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
