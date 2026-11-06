import 'package:flutter/material.dart';

import '../../../../../common/family/family_pairing_member.dart';
import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/show_localized_dialog.dart';

Future<bool> confirmFamilyDisconnect(
  BuildContext context,
  FamilyPairingMember member,
) async =>
    await showLocalizedDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.lang.setupDisconnectMember(member.displayName)),
        content: Text(context.lang.setupDisconnectDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.lang.setupDisconnectCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.lang.setupDisconnectConfirm),
          ),
        ],
      ),
    ) ??
    false;
