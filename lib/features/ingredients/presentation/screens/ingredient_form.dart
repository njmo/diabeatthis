import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/forms.dart';
import '../../data/providers/ingredient_provider.dart';

class IngredientForm extends HookConsumerWidget {
  IngredientForm({super.key});

  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(ingredientDraftProvider.notifier);

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.always,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                StringFormField(
                  label: 'Nazwa',
                  value: '',
                  onChanged: draft.setName,
                  builder: (context, controller) {
                    return TextFormField(
                      controller: controller,
                      maxLength: 30,
                      validator: (value) {
                        if ((value == null)) {
                          return 'Nazwa nie moze byc pusta';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Nazwa',
                        border: OutlineInputBorder(),
                      ),
                    );
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: StringFormField(
                        label: 'Ilość węglowodanów na 100g',
                        value: '0',
                        onChanged: draft.setCarbsPer100g,
                        builder: (context, controller) {
                          return TextFormField(
                            controller: controller,
                            maxLength: 30,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) {
                              if ((value == null)) {
                                return 'Ilość węglowodanów nie moze byc pusta';
                              }
                              return null;
                            },
                            decoration: const InputDecoration(
                              labelText: 'Weglowodany',
                              border: OutlineInputBorder(),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(width: 10,),
                    Expanded(
                      child: StringFormField(
                        label: 'Ilość tłuszczu na 100g',
                        value: '0',
                        onChanged: draft.setFatPer100g,
                        builder: (context, controller) {
                          return TextFormField(
                            controller: controller,
                            maxLength: 30,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) {
                              if ((value == null)) {
                                return 'Ilość tłuszczu nie moze byc pusta';
                              }
                              return null;
                            },
                            decoration: const InputDecoration(
                              labelText: 'Tłuszcz',
                              border: OutlineInputBorder(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: StringFormField(
                        label: 'Ilość białka na 100g',
                        value: '0',
                        onChanged: draft.setProteinPer100g,
                        builder: (context, controller) {
                          return TextFormField(
                            controller: controller,
                            maxLength: 30,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) {
                              if ((value == null)) {
                                return 'Ilość białka nie moze byc pusta';
                              }
                              return null;
                            },
                            decoration: const InputDecoration(
                              labelText: 'Białko',
                              border: OutlineInputBorder(),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(width: 10,),
                    Expanded(
                      child: StringFormField(
                        label: 'Ilość błonnika na 100g',
                        value: '0',
                        onChanged: draft.setFiberPer100g,
                        builder: (context, controller) {
                          return TextFormField(
                            controller: controller,
                            maxLength: 30,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) {
                              if ((value == null)) {
                                return 'Ilość błonnika nie moze byc pusta';
                              }
                              return null;
                            },
                            decoration: const InputDecoration(
                              labelText: 'Błonnik',
                              border: OutlineInputBorder(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final currentState = _formKey.currentState;
                            if (currentState != null && currentState.validate()) {
                              final ingredient = ref.read(
                                ingredientDraftProvider,
                              );
                              Navigator.of(context).pop(ingredient);
                            } else {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text('Blad w weryfikacji formularza')));
                            }
                          },
                          child: const Text('Add'),
                        ),
                      ),
                      SizedBox(width: 30,),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Discard'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
