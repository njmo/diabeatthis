import 'package:diabeatthis/common/l10n/generated/app_localizations.dart';
import 'package:diabeatthis/features/settings/presentation/setup/widgets/setup_family_status_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrapWithLocalization(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('renders loading state with title and explanation', (tester) async {
    await tester.pumpWidget(
      wrapWithLocalization(
        const SetupFamilyStatusNotice(isPending: true),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading family information…'), findsOneWidget);
    expect(
      find.text('Checking family group and linked accounts for this Google account.'),
      findsOneWidget,
    );
  });

  testWidgets('renders failed state with retry button', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      wrapWithLocalization(
        SetupFamilyStatusNotice(
          isPending: false,
          hasFailed: true,
          onRetry: () => retried = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.sync_problem), findsOneWidget);
    expect(find.text('Could not verify the linked accounts. Refresh the list to confirm pairing.'), findsOneWidget);
    expect(find.text('Refresh linked accounts'), findsOneWidget);

    await tester.tap(find.text('Refresh linked accounts'));
    expect(retried, isTrue);
  });

  testWidgets('renders locked state explaining disconnect requirement', (tester) async {
    await tester.pumpWidget(
      wrapWithLocalization(
        const SetupFamilyStatusNotice(isPending: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(
      find.text('Linked accounts must disconnect before family care can be turned off.'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
