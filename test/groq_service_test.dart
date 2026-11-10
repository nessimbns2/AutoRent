import 'dart:convert';

import 'package:autorent/core/services/groq_service.dart';
import 'package:autorent/core/utils/app_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a key saved in the app wins over the local key file', () async {
    // local groq_api_key.txt may or may not exist on this PC
    await GroqService.saveApiKey('gsk_from_settings');
    expect(await GroqService.apiKey(), 'gsk_from_settings');
  });

  test(
    'sends key, model, system prompt and history; returns the answer',
    () async {
      await GroqService.saveApiKey('gsk_test');
      late Map<String, dynamic> sent;
      late http.Request request;
      final groq = GroqService(
        client: MockClient((req) async {
          request = req;
          sent = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'role': 'assistant', 'content': ' Bonjour ! '},
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final answer = await groq.reply(
        systemPrompt: 'Tu es AutoRent',
        history: const [ChatMessage('user', 'Salut')],
      );

      expect(answer, 'Bonjour !');
      expect(request.url.toString(), GroqService.endpoint);
      expect(request.headers['Authorization'], 'Bearer gsk_test');
      expect(sent['model'], GroqService.defaultModel);
      expect((sent['messages'] as List).first, {
        'role': 'system',
        'content': 'Tu es AutoRent',
      });
      expect((sent['messages'] as List).last, {
        'role': 'user',
        'content': 'Salut',
      });
    },
  );

  test('refused key gives a clear message', () async {
    await GroqService.saveApiKey('gsk_bad');
    final groq = GroqService(
      client: MockClient((_) async => http.Response('{"error":"bad"}', 401)),
    );
    await expectLater(
      groq.reply(systemPrompt: 's', history: const [ChatMessage('user', 'x')]),
      throwsA(
        isA<AppException>().having(
          (e) => e.message,
          'message',
          contains('refusée'),
        ),
      ),
    );
  });

  test('a retired model is replaced by an available one', () async {
    await GroqService.saveModel('llama-3.3-70b-versatile');
    final asked = <String>[];
    final groq = GroqService(
      client: MockClient((req) async {
        if (req.method == 'GET') {
          return http.Response(
            jsonEncode({
              'data': [
                {'id': 'whisper-large-v3'},
                {'id': 'openai/gpt-oss-120b'},
              ],
            }),
            200,
          );
        }
        final model = (jsonDecode(req.body) as Map)['model'] as String;
        asked.add(model);
        if (model == 'llama-3.3-70b-versatile') {
          return http.Response(
            '{"error":{"message":"The model does not exist"}}',
            404,
          );
        }
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'OK'},
              },
            ],
          }),
          200,
        );
      }),
    );
    final answer = await groq.reply(
      systemPrompt: 's',
      history: const [ChatMessage('user', 'x')],
    );
    expect(answer, 'OK');
    expect(asked, ['llama-3.3-70b-versatile', 'openai/gpt-oss-120b']);
    expect(await GroqService.model(), 'openai/gpt-oss-120b');
  });
}
