import 'dart:convert';

import 'package:diabeatthis/common/analysis/dml_json.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'export precision is bounded without modifying original nested facts',
    () {
      final source = {
        'amount': 0.8519999999999999,
        'rows': [
          [1.8999999999999997, 154.38402104096878],
        ],
        'missing': double.nan,
        'large': 1e30,
      };
      final text = encodeDmlFacts(source);
      final result = jsonDecode(text) as Map;
      expect(result['amount'], 0.852);
      expect(result['rows'], [
        [1.9, 154.384],
      ]);
      expect(result['missing'], isNull);
      expect(result['large'], 1e30);
      expect(source['amount'], 0.8519999999999999);
      expect(source['missing'], isNaN);
    },
  );
}
