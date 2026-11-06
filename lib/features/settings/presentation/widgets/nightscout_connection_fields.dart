import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';

class NightscoutConnectionFields extends StatelessWidget {
  const NightscoutConnectionFields({
    super.key,
    this.initialUrl,
    this.initialToken,
    this.urlController,
    this.tokenController,
    this.onUrlSaved,
    this.onTokenSaved,
    this.onChanged,
    this.urlRequired = true,
    this.tokenRequired = false,
    this.enabled = true,
    this.urlLabel,
    this.tokenLabel,
    this.tokenRequiredError,
    this.urlSupporting,
    this.tokenSupporting,
  });

  final Widget? urlSupporting;
  final Widget? tokenSupporting;
  final String? urlLabel;
  final String? tokenLabel;
  final String? tokenRequiredError;
  final bool urlRequired;
  final bool tokenRequired;
  final bool enabled;
  final String? initialUrl;
  final String? initialToken;
  final TextEditingController? urlController;
  final TextEditingController? tokenController;
  final FormFieldSetter<String>? onUrlSaved;
  final FormFieldSetter<String>? onTokenSaved;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          enabled: enabled,
          initialValue: urlController == null ? initialUrl : null,
          controller: urlController,
          decoration: InputDecoration(
            labelText: urlLabel ?? context.lang.settingsNightscoutUrlLabel,
            hintText: context.lang.settingsNightscoutUrlHint,
          ),
          keyboardType: TextInputType.url,
          autocorrect: false,
          validator: (value) => _validateUrl(context, value),
          onSaved: onUrlSaved,
          onChanged: onChanged,
        ),
        if (urlSupporting != null) ...[
          const SizedBox(height: 8),
          urlSupporting!,
        ],
        const SizedBox(height: 16),
        TextFormField(
          enabled: enabled,
          initialValue: tokenController == null ? initialToken : null,
          controller: tokenController,
          decoration: InputDecoration(
            labelText: tokenLabel ?? context.lang.settingsNightscoutTokenLabel,
            hintText: context.lang.settingsNightscoutTokenHint,
          ),
          autocorrect: false,
          enableSuggestions: false,
          obscureText: true,
          validator: (value) => tokenRequired && (value?.trim().isEmpty ?? true)
              ? tokenRequiredError ??
                    context.lang.settingsTempTargetsTokenRequired
              : null,
          onSaved: onTokenSaved,
          onChanged: onChanged,
        ),
        if (tokenSupporting != null) ...[
          const SizedBox(height: 8),
          tokenSupporting!,
        ],
      ],
    );
  }

  String? _validateUrl(BuildContext context, String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return urlRequired ? context.lang.settingsNightscoutUrlRequired : null;
    }

    final uri = Uri.tryParse(text);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return context.lang.settingsNightscoutUrlInvalid;
    }

    return null;
  }
}
