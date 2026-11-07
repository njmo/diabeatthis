import 'dart:async';

import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/family/family_providers.dart';
import 'package:diabeatthis/common/family/family_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'family_settings_sheet_loading_test.dart' show LoadingFamilyRepository;

void main() {
  test(
    'empty roster from another account cannot authorize disabling family sync',
    () async {
      final accounts = StreamController<GoogleAccount?>.broadcast(sync: true);
      final repository = LoadingFamilyRepository();
      final container = ProviderContainer(
        overrides: [
          googleAccountProvider.overrideWith((ref) => accounts.stream),
          secureFamilyRepositoryProvider.overrideWithValue(repository),
        ],
      );
      container.listen(secureFamilyStatusProvider('first'), (_, _) {});
      accounts.add(const GoogleAccount(uid: 'first'));
      await Future<void>.delayed(Duration.zero);
      repository.statuses.add(const FamilyStatus());
      await Future<void>.delayed(Duration.zero);
      expect(
        container
            .read(secureFamilyStatusProvider('first'))
            .asData
            ?.value
            .members,
        isEmpty,
      );
      accounts.add(const GoogleAccount(uid: 'second'));
      await Future<void>.delayed(Duration.zero);
      container.listen(secureFamilyStatusProvider('second'), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      final status = container.read(secureFamilyStatusProvider('second'));
      expect(status.isLoading, isTrue);
      expect(status.asData, isNull);
      container.dispose();
      await accounts.close();
      await repository.statuses.close();
    },
  );
}
