import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../meals/presentation/widgets/confidence_slider.dart';
import '../../data/models/ingredient_details_data.dart';
import '../../data/models/ingredient_edit_draft.dart';

class IngredientEditMode extends StatefulWidget {
  final Ingredient ingredient;
  final bool isSaving;
  final VoidCallback onCancel;
  final Future<void> Function(IngredientEditDraft draft) onSave;

  const IngredientEditMode({
    super.key,
    required this.ingredient,
    required this.isSaving,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<IngredientEditMode> createState() => _IngredientEditModeState();
}

class _IngredientEditModeState extends State<IngredientEditMode> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;
  late final TextEditingController _fiberController;
  late final TextEditingController _proteinController;
  late ConfidenceLevel _confidence;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _carbsController = TextEditingController();
    _fatController = TextEditingController();
    _fiberController = TextEditingController();
    _proteinController = TextEditingController();
    _syncControllers(widget.ingredient);
  }

  @override
  void didUpdateWidget(covariant IngredientEditMode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ingredient.id != oldWidget.ingredient.id) {
      _syncControllers(widget.ingredient);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _fiberController.dispose();
    _proteinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.edit,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Edycja składnika',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                maxLength: 120,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nazwa',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (value) {
                  final name = value?.trim() ?? '';
                  if (name.isEmpty) {
                    return 'Podaj nazwę składnika';
                  }
                  if (name.length < 2) {
                    return 'Nazwa jest za krótka';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              ConfidenceSlider(
                value: _confidence,
                onChanged: (value) => setState(() => _confidence = value),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MacroTextField(
                      controller: _carbsController,
                      label: 'Węglowodany',
                      icon: Icons.grain,
                      validator: _validateMacro,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MacroTextField(
                      controller: _fatController,
                      label: 'Tłuszcz',
                      icon: Icons.opacity,
                      validator: _validateMacro,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MacroTextField(
                      controller: _proteinController,
                      label: 'Białko',
                      icon: Icons.fitness_center,
                      validator: _validateMacro,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MacroTextField(
                      controller: _fiberController,
                      label: 'Błonnik',
                      icon: Icons.eco_outlined,
                      validator: _validateMacro,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.isSaving ? null : widget.onCancel,
                    icon: const Icon(Icons.close),
                    label: const Text('Anuluj'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: widget.isSaving ? null : _save,
                    icon: widget.isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Zapisz'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await widget.onSave(
      IngredientEditDraft(
        ingredientId: widget.ingredient.id,
        name: _nameController.text,
        carbsPer100g: _parseDecimal(_carbsController.text)!,
        fatPer100g: _parseDecimal(_fatController.text)!,
        fiberPer100g: _parseDecimal(_fiberController.text)!,
        proteinPer100g: _parseDecimal(_proteinController.text)!,
        nutritionConfidence: _confidence.toDouble01(),
      ),
    );
  }

  void _syncControllers(Ingredient ingredient) {
    _nameController.text = ingredient.name;
    _carbsController.text = _formatInput(ingredient.carbsPer100g);
    _fatController.text = _formatInput(ingredient.fatPer100g);
    _fiberController.text = _formatInput(ingredient.fiberPer100g);
    _proteinController.text = _formatInput(ingredient.proteinPer100g);
    _confidence = ConfidenceLevelX.fromDouble01(ingredient.nutritionConfidence);
  }

  String? _validateMacro(String? value) {
    final parsed = _parseDecimal(value);
    if (parsed == null) {
      return 'Podaj liczbę';
    }
    if (parsed < 0) {
      return 'Nie może być ujemne';
    }
    return null;
  }
}

class _MacroTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final FormFieldValidator<String> validator;

  const _MacroTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
      decoration: InputDecoration(
        labelText: '$label / 100 g',
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
      ),
      validator: validator,
    );
  }
}

double? _parseDecimal(String? value) {
  final normalized = value?.trim().replaceAll(',', '.');
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return double.tryParse(normalized);
}

String _formatInput(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}
