import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_exception.dart';

/// One message of the assistant conversation.
class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  const ChatMessage(this.role, this.content);

  bool get isUser => role == 'user';

  Map<String, String> toJson() => {'role': role, 'content': content};
}

/// Chat with Groq through the Groq API (OpenAI-compatible endpoint).
///
/// The API key is never stored in the source code. It is read, in order:
/// 1. from the app settings (pasted in the assistant screen, kept in
///    SharedPreferences on this device only);
/// 2. from `--dart-define=GROQ_API_KEY=gsk_...` given to `flutter run`;
/// 3. from the git-ignored file `groq_api_key.txt` in the project folder.
class GroqService {
  GroqService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const endpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const modelsEndpoint = 'https://api.groq.com/openai/v1/models';
  static const defaultModel = 'openai/gpt-oss-120b';

  /// Chat models tried, in this order, when the configured one is retired.
  static const preferredModels = [
    'openai/gpt-oss-120b',
    'openai/gpt-oss-20b',
    'qwen/qwen3.8-27b',
  ];

  /// Groq models that are not chat models (speech, safety filters…).
  static bool _isChatModel(String id) => !RegExp(
    r'whisper|guard|orpheus|tts|playai',
    caseSensitive: false,
  ).hasMatch(id);
  static const _keyPref = 'groq_api_key';
  static const _modelPref = 'groq_model';
  static const _envKey = String.fromEnvironment('GROQ_API_KEY');

  static const _timeout = Duration(seconds: 60);

  /// Key saved on this device, or the one given with --dart-define.
  static Future<String?> apiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyPref)?.trim();
    if (saved != null && saved.isNotEmpty) return saved;
    if (_envKey.isNotEmpty) return _envKey;
    return _localFileKey();
  }

  /// Name of the git-ignored text file holding the key on a development
  /// PC (project folder, read when the app is started with `flutter run`).
  static const localKeyFile = 'groq_api_key.txt';

  static String? _localFileKey() {
    try {
      final f = File(localKeyFile);
      if (!f.existsSync()) return null;
      final k = f.readAsStringSync().trim();
      return k.isEmpty ? null : k;
    } catch (_) {
      return null; // web / mobile: no project folder
    }
  }

  static Future<bool> hasApiKey() async => (await apiKey()) != null;

  static Future<void> saveApiKey(String? key) async {
    final prefs = await SharedPreferences.getInstance();
    final k = key?.trim() ?? '';
    if (k.isEmpty) {
      await prefs.remove(_keyPref);
    } else {
      await prefs.setString(_keyPref, k);
    }
  }

  static Future<String> model() async {
    final prefs = await SharedPreferences.getInstance();
    final m = prefs.getString(_modelPref)?.trim();
    return (m == null || m.isEmpty) ? defaultModel : m;
  }

  static Future<void> saveModel(String? model) async {
    final prefs = await SharedPreferences.getInstance();
    final m = model?.trim() ?? '';
    if (m.isEmpty || m == defaultModel) {
      await prefs.remove(_modelPref);
    } else {
      await prefs.setString(_modelPref, m);
    }
  }

  /// Sends the conversation (preceded by [systemPrompt]) and returns
  /// Groq's answer. Throws an [AppException] with a French message.
  Future<String> reply({
    required String systemPrompt,
    required List<ChatMessage> history,
  }) async {
    final key = await apiKey();
    if (key == null) {
      throw const AppException(
        'Aucune clé API Groq : ajoutez-la avec le bouton ⚙ en haut à droite.',
      );
    }
    final current = await model();
    var res = await _send(key, current, systemPrompt, history);

    // The model was retired by Groq: pick an available one and retry once.
    if ((res.statusCode == 404 || res.statusCode == 400) &&
        _errorText(res.body).toLowerCase().contains('model')) {
      final replacement = await _availableModel(key, exclude: current);
      if (replacement != null) {
        await saveModel(replacement);
        res = await _send(key, replacement, systemPrompt, history);
      }
    }
    return _parse(res);
  }

  /// First available chat model (preferred ones first), or null.
  Future<String?> _availableModel(String key, {String? exclude}) async {
    try {
      final res = await _client
          .get(
            Uri.parse(modelsEndpoint),
            headers: {'Authorization': 'Bearer $key'},
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final ids = [
        for (final m in (jsonDecode(res.body)['data'] as List))
          if (m['active'] != false) m['id'] as String,
      ].where((id) => id != exclude && _isChatModel(id)).toList();
      for (final p in preferredModels) {
        if (ids.contains(p)) return p;
      }
      return ids.isEmpty ? null : ids.first;
    } catch (_) {
      return null;
    }
  }

  Future<http.Response> _send(
    String key,
    String model,
    String systemPrompt,
    List<ChatMessage> history,
  ) async {
    final body = jsonEncode({
      'model': model,
      'temperature': 0.4,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        // Keep the request small: the last 20 messages are enough context.
        for (final m
            in history.length > 20
                ? history.sublist(history.length - 20)
                : history)
          m.toJson(),
      ],
    });

    try {
      return await _client
          .post(
            Uri.parse(endpoint),
            headers: {
              'Authorization': 'Bearer $key',
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(_timeout);
    } catch (_) {
      throw const AppException(
        "Impossible de joindre Groq. Vérifiez votre connexion internet.",
      );
    }
  }

  String _parse(http.Response res) {
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw const AppException(
        'Clé API Groq refusée. Vérifiez-la dans les réglages de l\'assistant.',
      );
    }
    if (res.statusCode == 429) {
      throw const AppException(
        'Limite de requêtes Groq atteinte (ou crédits épuisés). Réessayez plus tard.',
      );
    }
    if (res.statusCode == 404 || res.statusCode == 400) {
      throw AppException(
        'Requête refusée par Groq (${res.statusCode}). Vérifiez le nom du modèle '
        'dans les réglages. ${_errorText(res.body)}',
      );
    }
    if (res.statusCode >= 300) {
      throw AppException(
        'Erreur Groq ${res.statusCode}. ${_errorText(res.body)}',
      );
    }

    try {
      final json =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final content =
          (json['choices'] as List).first['message']['content'] as String;
      return content.trim();
    } catch (_) {
      throw const AppException('Réponse de Groq illisible.');
    }
  }

  static String _errorText(String body) {
    try {
      final j = jsonDecode(body);
      final e = j['error'];
      if (e is String) return e;
      if (e is Map && e['message'] is String) return e['message'] as String;
    } catch (_) {}
    return '';
  }
}
