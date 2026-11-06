import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import 'google_brand_mark.dart';

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.busy = false,
  });
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: busy ? null : onPressed,
    style: OutlinedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xff1f1f1f),
      disabledBackgroundColor: Colors.white,
      disabledForegroundColor: const Color(0xff747775),
      side: const BorderSide(color: Color(0xff747775)),
      minimumSize: const Size(0, 52),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    ),
    icon: busy
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const GoogleBrandMark(),
    label: Text(context.lang.setupGoogleSignIn, textAlign: TextAlign.center),
  );
}
