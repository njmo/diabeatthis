import 'package:diabeatthis/common/l10n/generated/app_localizations_en.dart';
import 'package:diabeatthis/common/l10n/generated/app_localizations_pl.dart';
import 'package:diabeatthis/common/l10n/meal_entry_label.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'low treatment label comes from type and current UI language, including legacy names',
    () {
      for (final name in ['', 'Dosłodzenie (2)', 'Low treatment']) {
        expect(
          mealEntryLabel(
            purpose: MealPurpose.lowTreatment,
            name: name,
            lang: AppLocalizationsPl(),
          ),
          'Dosłodzenie',
        );
        expect(
          mealEntryLabel(
            purpose: MealPurpose.lowTreatment,
            name: name,
            lang: AppLocalizationsEn(),
          ),
          'Low treatment',
        );
      }
      expect(
        mealEntryLabel(
          purpose: MealPurpose.meal,
          name: 'Breakfast',
          lang: AppLocalizationsPl(),
        ),
        'Breakfast',
      );
    },
  );
}
