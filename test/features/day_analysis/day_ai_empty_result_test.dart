import 'dart:convert';

import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_result.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_ai_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'day_analysis_api_test.dart' show analysisResponse;

void main() {
  testWidgets(
    'empty insufficient analysis cannot be mistaken for no findings',
    (tester) async {
      final json = analysisResponse();
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: DayAiResult(
              result: DayAnalysisResult.parse(
                jsonEncode(json),
                language: 'pl',
                evidenceIds: {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('Za mało danych do pełnej oceny.'), findsOneWidget);
      for (final section in (json['sections'] as Map).values) {
        section['status'] = 'ok';
        section['missing_data'] = [];
      }
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: DayAiResult(
              result: DayAnalysisResult.parse(
                jsonEncode(json),
                language: 'pl',
                evidenceIds: {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('Za mało danych do pełnej oceny.'), findsNothing);
      expect(find.byType(Text), findsOneWidget);
    },
  );
}
