import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/provider/shared_prefs_provider.dart';

const _nightscoutUrlKey = 'nightscout_url';

class NightscoutGuard extends AutoRouteGuard {
  NightscoutGuard(this.ref);

  final Ref ref;

  @override
  void onNavigation(
      NavigationResolver resolver,
      StackRouter router,
      ) {
    _handleNavigation(resolver, router);
  }

  Future<void> _handleNavigation(
      NavigationResolver resolver,
      StackRouter router,
      ) async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    final url = prefs.getString(_nightscoutUrlKey);

    if (url != null && url.isNotEmpty) {
      resolver.next(true);
    } else {
      router.navigate(NamedRoute('NightscoutSetupRoute'));
    }
  }
}
