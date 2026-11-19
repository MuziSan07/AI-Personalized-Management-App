import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GroqException implements Exception {
  GroqException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Thin client for Groq Cloud's OpenAI-compatible chat completions API.
class GroqService {
  GroqService({String? modelOverride}) : _modelOverride = modelOverride;

  static const _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const defaultModel = 'llama-3.3-70b-versatile';

  static const availableModels = <String>[
    'llama-3.3-70b-versatile',
    'llama-3.1-8b-instant',
    'openai/gpt-oss-120b',
    'openai/gpt-oss-20b',
    'meta-llama/llama-4-scout-17b-16e-instruct',
    'qwen/qwen3-32b',
  ];

  final String? _modelOverride;

  static String _env(String key) {
    if (!dotenv.isInitialized) return '';
    return (dotenv.maybeGet(key) ?? '').trim();
  }

  static String get apiKey => _env('GROQ_API_KEY');

  static bool get isConfigured =>
      apiKey.isNotEmpty && apiKey != 'your_groq_api_key_here';

  String get model {
    final o = _modelOverride?.trim();
    if (o != null && o.isNotEmpty) return o;
    final env = _env('GROQ_MODEL');
    if (env.isNotEmpty) return env;
    return defaultModel;
  }

  /// Sends [messages] (`{role, content}` maps) and returns the assistant text.
  Future<String> chat(
    List<Map<String, String>> messages, {
    bool jsonMode = false,
    double temperature = 0.6,
    int maxTokens = 1500,
  }) async {
    if (!isConfigured) {
      throw GroqException(
          'Groq API key missing. Add GROQ_API_KEY to the .env file and restart the app.');
    }
    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
      if (jsonMode) 'response_format': {'type': 'json_object'},
    };
    http.Response res;
    try {
      res = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));
    } catch (e) {
      throw GroqException('Network error talking to Groq: $e');
    }
    if (res.statusCode != 200) {
      String msg = 'Groq error ${res.statusCode}';
      try {
        final j = jsonDecode(res.body);
        msg = '$msg: ${j['error']?['message'] ?? res.body}';
      } catch (_) {
        msg = '$msg: ${res.body}';
      }
      throw GroqException(msg);
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw GroqException('Groq returned no choices.');
    }
    return (choices.first['message']['content'] as String? ?? '').trim();
  }

  /// Like [chat] but forces a JSON object response and decodes it.
  Future<Map<String, dynamic>> chatJson(
    List<Map<String, String>> messages, {
    double temperature = 0.2,
    int maxTokens = 1500,
  }) async {
    final text = await chat(messages,
        jsonMode: true, temperature: temperature, maxTokens: maxTokens);
    return _decodeJson(text);
  }

  static Map<String, dynamic> _decodeJson(String text) {
    var t = text.trim();
    // Strip ```json fences if the model added them anyway.
    if (t.startsWith('```')) {
      t = t.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
      t = t.replaceFirst(RegExp(r'```\s*$'), '');
    }
    final start = t.indexOf('{');
    final end = t.lastIndexOf('}');
    if (start >= 0 && end > start) t = t.substring(start, end + 1);
    try {
      final v = jsonDecode(t);
      if (v is Map<String, dynamic>) return v;
      throw GroqException('Model returned non-object JSON.');
    } on FormatException {
      throw GroqException('Could not parse the model\'s JSON response.');
    }
  }
}
