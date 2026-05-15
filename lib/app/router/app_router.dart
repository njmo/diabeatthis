import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';

import '../../features/activity/presentation/screens/activity_log_page.dart';
import '../../features/activity/presentation/screens/activity_page.dart';
import '../../features/dashboard/presentation/screens/dashboard_page.dart';
import '../../features/ingredients/presentation/screens/ingredient_page.dart';
import '../../features/management/presentation/screens/management_page.dart';
import '../../features/meal_summary/presentation/screens/meal_summary_page.dart';
import '../../features/meal_template/presentation/screens/add_meal_template_page.dart';
import '../../features/meals/presentation/screens/add_meal_page.dart';
import '../../features/meals/presentation/screens/meal_page.dart';
import '../../features/settings/presentation/screens/initial_configuration_page.dart';
import '../../features/settings/presentation/screens/settings_page.dart';
import '../../features/test/presentation/screens/test_page.dart';
import 'guards/initial_configuration_guard.dart';

part 'app_router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Screen|Page,Route')
class AppRouter extends RootStackRouter {
  final InitialConfigurationGuard guard;

  @override
  RouteType get defaultRouteType => RouteType.material();

  AppRouter(this.guard);

  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: DashboardRoute.page, path: '/', guards: [guard]),
    AutoRoute(page: TestRoute.page),
    AutoRoute(
      page: InitialConfigurationRoute.page,
      path: '/initial-configuration',
    ),
    AutoRoute(page: SettingsRoute.page, path: '/settings'),
    AutoRoute(page: AddMealRoute.page),
    AutoRoute(page: AddMealTemplateRoute.page),
    AutoRoute(page: ManagementRoute.page, path: '/management'),
    AutoRoute(page: MealSummaryRoute.page, path: '/meal-summary/:mealId'),
    AutoRoute(page: MealRoute.page, path: '/meal/:mealId'),
    AutoRoute(page: IngredientRoute.page, path: '/ingredient/:ingredientId'),
    AutoRoute(page: ActivityRoute.page, path: '/activity/:activityId'),
    AutoRoute(
      page: ActivityLogRoute.page,
      path: '/activity-log/:activityLogId',
    ),
  ];

  @override
  List<AutoRouteGuard> get guards => [];
}
