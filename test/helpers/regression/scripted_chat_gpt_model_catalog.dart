import 'package:diabeatthis/common/ai/ai_model_option.dart';
import 'package:diabeatthis/common/ai/chat_gpt_model_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scripted_read.dart';

class ScriptedChatGptModelCatalog extends Fake implements ChatGptModelCatalog {
  final ScriptedRead<List<AiModelOption>> reads;
  ScriptedChatGptModelCatalog(this.reads);

  @override
  Future<List<AiModelOption>> load() => reads([]);
}
