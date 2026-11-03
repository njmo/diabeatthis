import 'package:diabeatthis/common/ai/auth/chat_gpt_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scripted_read.dart';

class ScriptedChatGptAuthService extends Fake implements ChatGptAuthService {
  final ScriptedRead<bool> connected;
  final ScriptedRead<void> commands;
  ScriptedChatGptAuthService(this.connected, this.commands);

  @override
  Future<bool> get isConnected => connected([]);
  @override
  Future<void> signIn() => commands(['signIn']);
  @override
  Future<void> signOut() => commands(['signOut']);
}
