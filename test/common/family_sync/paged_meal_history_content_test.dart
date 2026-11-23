import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/presentation/collections/views/meals_view.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('an incomplete empty history loads without claiming no meals', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_list(loading: true)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Brak posiłków'), findsNothing);
    await tester.pumpWidget(_app(_list()));
    expect(find.text('Brak posiłków'), findsOneWidget);
  });

  testWidgets('a short history page has a reachable load-more button', (
    tester,
  ) async {
    var loads = 0;
    await tester.pumpWidget(_app(_list(
      meals: [Meal(id: 1, name: 'Zupa', status: 'planned')],
      hasMore: true,
      loadMore: () => loads++,
    )));
    await tester.tap(find.text('Pokaż więcej'));
    expect(loads, 1);
  });
}

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('pl'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

Widget _list({
  List<Meal> meals = const [],
  bool loading = false,
  bool hasMore = false,
  VoidCallback? loadMore,
}) => MealListContent(
  meals: meals,
  isInitialLoading: loading,
  isLoadingMore: false,
  hasMore: hasMore,
  hasError: false,
  allowManualLoadMore: true,
  onLoadMore: loadMore ?? () {},
  onRetry: () {},
  onMealTap: (_) {},
  onMealDelete: null,
);
