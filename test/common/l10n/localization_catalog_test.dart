import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Polish and English catalogs have matching keys and no orphan metadata',
    () {
      Map<String, dynamic> read(String locale) =>
          jsonDecode(File('lib/common/l10n/app_$locale.arb').readAsStringSync())
              as Map<String, dynamic>;
      final polish = read('pl');
      final english = read('en');
      Set<String> messages(Map<String, dynamic> catalog) =>
          catalog.keys.where((key) => !key.startsWith('@')).toSet();
      expect(messages(english), messages(polish));
      for (final catalog in [polish, english]) {
        for (final key in catalog.keys.where(
          (key) => key.startsWith('@') && !key.startsWith('@@'),
        )) {
          expect(
            catalog.containsKey(key.substring(1)),
            isTrue,
            reason: 'Orphan metadata: $key',
          );
        }
      }
    },
  );
}
