import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/domain/model/bolus_wizard.dart';

part 'latest_bolus_wizard_provider.g.dart';

@Riverpod(keepAlive: true)
class LatestBolusWizard extends _$LatestBolusWizard {
  @override
  BolusWizard? build() {
    return null;
  }

  void update(BolusWizard bolusWizard) {
    state = bolusWizard;
  }

  void clear() {
    state = null;
  }
}
