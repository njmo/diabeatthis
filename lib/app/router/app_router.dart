import 'package:auto_route/auto_route.dart';

import '../../features/dashboard/presentation/screens/dashboard_page.dart';

part 'app_router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Screen|Page,Route')
class AppRouter extends RootStackRouter {
  @override
  RouteType get defaultRouteType => RouteType.material();

  @override
  List<AutoRoute> get routes => [
    // DashboardPage is generated as DashboardRoute because
    // of the replaceInRouteName property
    AutoRoute(page: DashboardRoute.page, path: '/'),
  ];

  @override
  List<AutoRouteGuard> get guards => [
    // optionally add root guards here
  ];
}
