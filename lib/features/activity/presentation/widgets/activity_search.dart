import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/forms.dart';
import '../../../../core/domain/model/activity.dart';
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

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.25,
      width: MediaQuery.of(context).size.width * 0.8,
      child: Column(
        children: [
          Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.always,
            child: StringFormField(
              label: 'Nazwa',
              value: '',
              onChanged: (value) => query.value = value,
              builder: (context, controller) {
                return TextFormField(
                  autofocus: true,
                  controller: controller,
                  maxLength: 30,
                  validator: (value) {
                    if (valuePicked.value < 0) return '';
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
          const SizedBox(height: 8),
          activities.when(
            data: (data) {
              if (data.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Brak wyników'),
                );
              }
              return Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final activity = data[index];
                    return ListTile(
                      title: Text(
                        activity.whenOrNull(
                              existing: (_, name, _, _, _) => name,
                            ) ??
                            '',
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
                ),
              );
            },
            error: (error, _) => Text(error.toString()),
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 16),
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      ),
    );
  }
}
