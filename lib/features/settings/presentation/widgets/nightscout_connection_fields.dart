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
  });

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
            labelText: context.lang.settingsNightscoutUrlLabel,
            hintText: context.lang.settingsNightscoutUrlHint,
          ),
          keyboardType: TextInputType.url,
          autocorrect: false,
          validator: (value) => _validateUrl(context, value),
          onSaved: onUrlSaved,
          onChanged: onChanged,
        ),
        const SizedBox(height: 16),
        TextFormField(
          enabled: enabled,
          initialValue: tokenController == null ? initialToken : null,
          controller: tokenController,
          decoration: InputDecoration(
            labelText: context.lang.settingsNightscoutTokenLabel,
            hintText: context.lang.settingsNightscoutTokenHint,
          ),
          autocorrect: false,
          enableSuggestions: false,
          obscureText: true,
          validator: (value) => tokenRequired && (value?.trim().isEmpty ?? true)
              ? context.lang.settingsTempTargetsTokenRequired
              : null,
          onSaved: onTokenSaved,
          onChanged: onChanged,
        ),
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
