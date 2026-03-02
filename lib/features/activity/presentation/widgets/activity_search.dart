import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/forms.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../data/providers/activity_provider.dart';

class ActivitySearch extends HookConsumerWidget {
  const ActivitySearch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = useState('');
    final valuePicked = useState(-1);
    final activities = ref.watch(activitiesByQueryProvider(query.value));
    final draft = ref.watch(activityDraftProvider.notifier);
    final formKey = ref.watch(mealIngredientFormKeyProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          activities.when(
            data: (data) {
              return SizedBox(
                height: 200,
                child: SafeArea(
                  child: ListView.builder(
                    itemBuilder: (context, index) {
                      if (data.isEmpty) return Text('No data');
                      final activity = data[index];
                      return ListTile(
                        title: Text(
                          activity.name ?? '',
                          style: TextStyle(
                            fontWeight: (valuePicked.value == index)
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        onTap: () {
                          draft.overrideDraft(activity);
                          valuePicked.value = index;
                        },
                      );
                    },
                    itemCount: data.length,
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
