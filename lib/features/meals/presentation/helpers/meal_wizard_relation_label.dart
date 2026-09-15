import '../../../../common/l10n/language.dart';
import '../../common/models/meal_wizard_relation_type.dart';

extension MealWizardRelationLabel on MealWizardRelationType {
  String get label => switch (this) {
    MealWizardRelationType.initial => lang.uiFirstPart,
    MealWizardRelationType.continuation => lang.uiNextPart,
    MealWizardRelationType.correction => lang.uiMealCorrection,
  };
}
