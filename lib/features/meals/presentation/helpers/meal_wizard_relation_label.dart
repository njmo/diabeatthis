import '../../common/models/meal_wizard_relation_type.dart';

extension MealWizardRelationLabel on MealWizardRelationType {
  String get label => switch (this) {
    MealWizardRelationType.initial => 'Pierwsza część',
    MealWizardRelationType.continuation => 'Kolejna część',
    MealWizardRelationType.correction => 'Korekta posiłku',
  };
}
