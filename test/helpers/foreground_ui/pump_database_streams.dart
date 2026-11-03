import 'package:flutter_test/flutter_test.dart';

/// Allows real shared-database messages and fake-frame provider continuations
/// to advance together. A loading indicator alone cannot drive native I/O.
Future<void> pumpDatabaseStreams(WidgetTester tester) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
}
