import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/provider/initial_configuration_provider.dart';

class InitialConfigurationGuard extends AutoRouteGuard {
  InitialConfigurationGuard(this.ref);

  final Ref ref;

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    _handleNavigation(resolver, router);
  }

  Future<void> _handleNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async {
    final isInitialConfigurationDone = await ref.read(
      initialConfigurationDoneProvider.future,
    );

    if (isInitialConfigurationDone) {
      resolver.next(true);
    } else {
      router.navigate(NamedRoute('InitialConfigurationRoute'));
    }
  }
}
