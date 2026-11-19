import 'package:diabeatthis/features/dashboard/presentation/widgets/compact_loop_glucose_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('prediction help opens on tap and dismisses outside', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: AapsPredictionHelp())),
      ),
    );
    expect(find.textContaining('insulin on board'), findsNothing);
    final target = find.byType(AapsPredictionHelp);
    expect(tester.getSize(target), const Size(40, 40));
    await tester.tapAt(tester.getTopLeft(target) + const Offset(3, 3));
    await tester.pumpAndSettle();
    for (final label in [
      'insulin on board',
      'carbs on board',
      'unannounced meals',
      'zero temp',
    ]) {
      expect(find.textContaining(label), findsOneWidget);
    }
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.textContaining('insulin on board'), findsNothing);
  });
}
