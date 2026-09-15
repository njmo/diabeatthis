import 'dart:ui';

import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/features/meals/presentation/utils/meal_ingredient_portion_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'stored unit names work after switching languages in either direction',
    () {
      addTearDown(() => LanguageStrings.setSelectedLocale(const Locale('pl')));
      LanguageStrings.setSelectedLocale(const Locale('pl'));
      expect(unitLabelForAmount(2, 'portion'), 'porcje');
      expect(unitLabelForAmount(5, 'piece'), 'sztuk');
      LanguageStrings.setSelectedLocale(const Locale('en'));
      expect(unitLabelForAmount(2, 'porcja'), 'portions');
      expect(unitLabelForAmount(5, 'sztuka'), 'pieces');
      expect(unitLabelForAmount(2, 'custom cup'), 'custom cup');
    },
  );
}
