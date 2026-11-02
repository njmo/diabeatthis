import 'dart:convert';

import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/features/meal_analysis/data/clients/llm_meal_ai_client.dart';
import 'package:diabeatthis/features/meal_analysis/data/prompts/meal_ai_prompt.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_ai_invalid_response.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_ai_test_fixtures.dart';

class ScriptedMealAnalysisTransport implements LocalLlmClient {
  final List<String> responses;
  final requests = <LocalLlmRequest>[];

  ScriptedMealAnalysisTransport(this.responses);

  @override
  Future<LocalLlmResponse> generate(LocalLlmRequest request) async {
    requests.add(request);
    return LocalLlmResponse(text: responses[requests.length - 1]);
  }
}

void main() {
  test(
    'invalid references trigger one replacement using original evidence',
    () async {
      final document = await aiDocument();
      final valid = aiResponse();
      final transport = ScriptedMealAnalysisTransport([
        aiResponse(reference: 'meal_cgm.blocks[0].rows[8]'),
        valid,
      ]);
      final result = await LlmMealAiClient(
        transport: transport,
        modelId: 'test',
      ).analyze(document, language: 'pl');

      expect(result.text, valid);
      expect(transport.requests, hasLength(2));
      expect(result.prompt, transport.requests.last.prompt);
      expect(result.prompt, contains(document.text));
      expect(result.prompt, contains('Unknown or missing evidence'));
      expect(
        transport.requests.last.timeout! <= transport.requests.first.timeout!,
        isTrue,
      );
    },
  );

  test('extra findings trigger recovery without relaxing validation', () async {
    final response = jsonDecode(aiResponse()) as Map<String, dynamic>;
    final findings = response['sections']['response']['findings'] as List;
    findings.add(Map<String, dynamic>.from(findings.first as Map));
    final transport = ScriptedMealAnalysisTransport([
      jsonEncode(response),
      aiResponse(),
    ]);
    await LlmMealAiClient(
      transport: transport,
      modelId: 'test',
    ).analyze(await aiDocument(), language: 'pl');

    expect(transport.requests, hasLength(2));
    expect(transport.requests.last.prompt, contains('Too many findings'));
  });

  test(
    'second invalid response remains inspectable and stops retries',
    () async {
      final transport = ScriptedMealAnalysisTransport([
        '{',
        '{"invalid":true}',
      ]);
      await expectLater(
        LlmMealAiClient(
          transport: transport,
          modelId: 'test',
        ).analyze(await aiDocument(), language: 'pl'),
        throwsA(
          isA<MealAiInvalidResponse>().having(
            (error) => error.response,
            'last raw response',
            '{"invalid":true}',
          ),
        ),
      );
      expect(transport.requests, hasLength(2));
    },
  );

  test(
    'valid response needs no retry and prompt lists actual nested paths',
    () async {
      final document = await aiDocument();
      final prompt = buildMealAiPrompt(document, 'pl');
      expect(prompt, contains('meal.recorded_timing.eating_started_at'));
      final transport = ScriptedMealAnalysisTransport([aiResponse()]);
      await LlmMealAiClient(
        transport: transport,
        modelId: 'test',
      ).analyze(document, language: 'pl');
      expect(transport.requests, hasLength(1));
    },
  );
}
