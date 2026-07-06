import 'package:flutter/material.dart';

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
  });

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
          initialValue: urlController == null ? initialUrl : null,
          controller: urlController,
          decoration: const InputDecoration(
            labelText: 'Nightscout URL',
            hintText: 'https://twoj-nightscout.com',
          ),
          keyboardType: TextInputType.url,
          autocorrect: false,
          validator: _validateUrl,
          onSaved: onUrlSaved,
          onChanged: onChanged,
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: tokenController == null ? initialToken : null,
          controller: tokenController,
          decoration: const InputDecoration(
            labelText: 'Token Nightscout',
            hintText: 'Opcjonalny token dla prywatnej strony',
          ),
          autocorrect: false,
          enableSuggestions: false,
          obscureText: true,
          onSaved: onTokenSaved,
          onChanged: onChanged,
        ),
      ],
    );
  }

  String? _validateUrl(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Podaj adres Nightscout';
    }

    final uri = Uri.tryParse(text);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return 'Podaj poprawny adres URL';
    }

    return null;
  }
}
