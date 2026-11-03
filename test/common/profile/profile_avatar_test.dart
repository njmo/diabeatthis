import 'package:diabeatthis/common/widgets/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows initials when no photo is assigned', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ProfileAvatar(name: 'Maria Kowalska')),
      ),
    );
    expect(find.text('MK'), findsOneWidget);
  });

  testWidgets('shows person icon without a photo or name', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProfileAvatar())),
    );
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });

  testWidgets('falls back to initials when the assigned file is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileAvatar(
            name: 'Maria',
            photoPath: '/missing/profile-photo.jpg',
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.text('M'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
