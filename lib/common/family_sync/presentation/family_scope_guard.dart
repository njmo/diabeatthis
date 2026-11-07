import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/google_authentication_providers.dart';
import '../../l10n/language.dart';
import '../../routing/form_route_guard.dart';
import '../family_access_scope.dart';

class FamilyScopeGuard extends ConsumerWidget {
  const FamilyScopeGuard({super.key, required this.scope, required this.child});
  final FamilyAccessScope scope;
  final Widget child;
  Widget unavailable(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: Center(child: Text(context.lang.familyPlanFailed)),
  );
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(googleAccountProvider);
    return StreamBuilder<void>(
      stream: scope.family.whenDisposed,
      builder: (context, _) {
        if (scope.family.disposed) return unavailable(context);
        return ListenableBuilder(
          listenable: scope.family,
          builder: (context, _) => scope.isCurrent
              ? ProviderScope(
                  overrides: [
                    formRouteGuardProvider.overrideWithValue(
                      (nested) => FamilyScopeGuard(scope: scope, child: nested),
                    ),
                  ],
                  child: child,
                )
              : unavailable(context),
        );
      },
    );
  }
}
