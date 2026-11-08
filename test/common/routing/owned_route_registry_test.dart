import 'package:diabeatthis/common/routing/owned_route_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('closes only active routes belonging to the requested owner', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: const Text('Home')),
    );
    final first = Object();
    final second = Object();
    Route<void> route(String label) =>
        MaterialPageRoute<void>(builder: (_) => Scaffold(body: Text(label)));
    final a = route('First');
    final nested = route('Nested');
    final b = route('Other');
    for (final entry in [(first, a), (first, nested), (second, b)]) {
      OwnedRouteRegistry.register(entry.$1, entry.$2);
      navigator.currentState!.push(entry.$2);
      await tester.pumpAndSettle();
    }
    OwnedRouteRegistry.close(first);
    await tester.pumpAndSettle();
    expect(find.text('Other'), findsOneWidget);
    expect(a.isActive, isFalse);
    expect(nested.isActive, isFalse);
    expect(b.isActive, isTrue);
    OwnedRouteRegistry.close(second);
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });
}
