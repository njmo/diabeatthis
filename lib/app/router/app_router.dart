import 'package:auto_route/auto_route.dart';

import '../../features/dashboard/presentation/screens/dashboard_page.dart';
import '../../features/meal_template/presentation/screens/add_meal_template_page.dart';
import '../../features/meals/presentation/screens/add_meal_page.dart';
import '../../features/settings/presentation/screens/settings_page.dart';
import '../../features/test/presentation/screens/test_page.dart';
import 'guards/nightscout_config_guard.dart';

part 'app_router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Screen|Page,Route')
class AppRouter extends RootStackRouter {
  final NightscoutGuard guard;
  @override
  RouteType get defaultRouteType => RouteType.material();

  AppRouter(this.guard);

  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: DashboardRoute.page, path: '/', guards: [guard]),
    AutoRoute(page: TestRoute.page),
    AutoRoute(page: SettingsRoute.page, path: '/settings'),
    AutoRoute(page: AddMealRoute.page),
    AutoRoute(page: AddMealTemplateRoute.page),
  ];

  @override
  List<AutoRouteGuard> get guards => [
  ];
}
