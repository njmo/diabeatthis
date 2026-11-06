import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import '../family_join_request.dart';
import 'family_account_avatar.dart';

class FamilyPendingRequestCard extends StatelessWidget {
  const FamilyPendingRequestCard({
    super.key,
    required this.request,
    required this.busy,
    required this.onDecide,
  });
  final FamilyJoinRequest request;
  final bool busy;
  final void Function(bool approve) onDecide;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.lang.familyApprovalTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: FamilyAccountAvatar(photoUrl: request.photoUrl),
            title: Text(request.displayName),
            subtitle: Text(request.email),
          ),
          Text(context.lang.familyApprovalExplanation),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: [
              TextButton(
                onPressed: busy ? null : () => onDecide(false),
                child: Text(context.lang.familyReject),
              ),
              FilledButton(
                onPressed: busy ? null : () => onDecide(true),
                child: Text(context.lang.familyApprove),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
