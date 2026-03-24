import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/forms.dart';
import '../../../../core/logger/logger.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../data/drafts/portion_filter.dart';
import '../../data/mappers/portion_draft_mapper.dart';
import '../../data/providers/portion_provider.dart';

class PortionSearch extends HookConsumerWidget with Logging {
  const PortionSearch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = useState('');
    final valuePicked = useState(-1);
    final filter = ref.watch(portionFilterProvider);
    final portions = filter.map(
      all: (_) => ref.watch(portionsProvider),
      byQuery: (filter) => ref.watch(portionsByQueryProvider(query.value)),
      byQueryForIngredient: (filter) => ref.watch(
        portionsByIngredientByQueryProvider(filter.ingredientId, query.value),
      ),
      allUnassignedForIngredient: (filter) => ref.watch(
        portionsNotInIngredientByQueryProvider(
          filter.ingredientId,
          query.value,
        ),
      ),
    );
    logI("Filter : $filter");
    final draft = ref.watch(portionDraftProvider.notifier);
    final formKey = ref.watch(mealIngredientFormKeyProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.always,
            child: StringFormField(
              label: 'Nazwa',
              value: '',
              onChanged: (value) {
                query.value = value;
              },
              builder: (context, controller) {
                return TextFormField(
                  autofocus: true,
                  controller: controller,
                  maxLength: 30,
                  validator: (value) {
                    if (valuePicked.value < 0) {
                      return '';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    icon: Icon(Icons.search),
                    labelText: 'Nazwa',
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
          ),
          portions.when(
            data: (data) {
              return SizedBox(
                height: 200,
                child: SafeArea(
                  child: ListView.builder(
                    itemBuilder: (context, index) {
                      if (data.isEmpty) return Text('No data');
                      final portion = data[index];
                      return ListTile(
                        title: Text(
                          portion.name,
                          style: TextStyle(
                            fontWeight: (valuePicked.value == index)
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(portion.unitHint),
                        onTap: () {
                          draft.overrideDraft(portion.toSelection());
                          valuePicked.value = index;
                        },
                      );
                    },
                    itemCount: data.length,
                    shrinkWrap: true,
                  ),
                ),
              );
            },
            error: (error, stackTrace) => Text(error.toString()),
            loading: () => CircularProgressIndicator(),
          ),
        ],
      ),
    );
  }
}
