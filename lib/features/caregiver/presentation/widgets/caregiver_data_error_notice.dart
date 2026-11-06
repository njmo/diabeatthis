import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/analysis_error_notice.dart';
import '../../data/caregiver_visible_state_provider.dart';

class CaregiverDataErrorNotice extends ConsumerWidget {
  const CaregiverDataErrorNotice({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(caregiverVisibleStateProvider).failed) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: AnalysisErrorNotice(
        message: context.lang.caregiverDataRefreshFailed,
      ),
    );
  }
}
