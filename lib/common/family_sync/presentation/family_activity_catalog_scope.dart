import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../planning/activity_catalog_repository.dart';
import '../../routing/form_route_guard.dart';
import '../family_access_scope.dart';
import '../firebase_activity_catalog_repository.dart';
import 'family_scope_guard.dart';

class FamilyActivityCatalogScope extends HookWidget {
  const FamilyActivityCatalogScope({
    super.key,
    required this.scope,
    required this.child,
  });
  final FamilyAccessScope scope;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final repository = useMemoized(
      () => FirebaseActivityCatalogRepository(scope),
      [scope],
    );
    return FamilyScopeGuard(
      scope: scope,
      child: ProviderScope(
        overrides: [
          activityCatalogRepositoryProvider.overrideWithValue(repository),
          activityCatalogMaximumDurationProvider.overrideWithValue(1440),
          formRouteGuardProvider.overrideWithValue(
            (nested) => FamilyActivityCatalogScope(scope: scope, child: nested),
          ),
        ],
        child: child,
      ),
    );
  }
}
