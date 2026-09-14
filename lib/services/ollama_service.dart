import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OllamaService {
  OllamaService({String? baseUrl, String? model})
      : _customBaseUrl = baseUrl,
        _defaultModel = model ?? 'qwen3.8';

  static const String _prefHostKey = 'nex_ollama_custom_host';
  static const String _prefModelKey = 'nex_ollama_custom_model';

  String? _customBaseUrl;
  String _defaultModel;

  Future<String> getBaseUrl() async {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefHostKey);
      if (saved != null && saved.trim().isNotEmpty) {
        return saved.trim();
      }
    } catch (_) {}

    const envValue = String.fromEnvironment('OLLAMA_BASE_URL', defaultValue: '');
    if (envValue.isNotEmpty) return envValue;

    return Platform.isAndroid ? 'http://10.0.2.2:11434' : 'http://127.0.0.1:11434';
  }

  Future<void> setCustomHost(String url) async {
    _customBaseUrl = url.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefHostKey, _customBaseUrl!);
    } catch (_) {}
  }

  Future<String> getSelectedModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefModelKey);
      if (saved != null && saved.trim().isNotEmpty) {
        return saved.trim();
      }
    } catch (_) {}
    return _defaultModel;
  }

  Future<void> setSelectedModel(String model) async {
    _defaultModel = model.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefModelKey, _defaultModel);
    } catch (_) {}
  }

  Map<String, dynamic> buildRequestBody(String prompt, {String? model, String systemPrompt = ''}) {
    final messages = <Map<String, String>>[];
    if (systemPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({'role': 'user', 'content': prompt});

    return {
      'model': model ?? _defaultModel,
      'stream': false,
      'messages': messages,
      'options': {
        'temperature': 0.7,
        'top_p': 0.9,
      },
    };
  }

  String extractMessageContent(String body) {
    final decoded = jsonDecode(body);
    final content = decoded['message']?['content'] ?? decoded['response'];
    if (content is String && content.trim().isNotEmpty) {
      return content.trim();
    }
    throw Exception('Ollama response did not contain message content.');
  }

  Future<String> chat(String prompt, {String? model, String systemPrompt = ''}) async {
    final baseUrl = await getBaseUrl();
    final targetModel = model ?? await getSelectedModel();
    final uri = Uri.parse('$baseUrl/api/chat');
    final payload = jsonEncode(buildRequestBody(prompt, model: targetModel, systemPrompt: systemPrompt));

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);

    try {
      final request = await client.postUrl(uri).timeout(const Duration(seconds: 5));
      request.headers.set('Content-Type', 'application/json');
      request.write(payload);

      final response = await request.close().timeout(const Duration(seconds: 15));
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return extractMessageContent(body);
      }

      throw Exception('Ollama server returned HTTP ${response.statusCode}');
    } on SocketException catch (e) {
      throw Exception('Cannot reach Ollama at $baseUrl ($e). Make sure Ollama server is running and accessible.');
    } catch (e) {
      if (kDebugMode) debugPrint('[OllamaService] Chat request error: $e');
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> isAvailable() async {
    final baseUrl = await getBaseUrl();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final uri = Uri.parse('$baseUrl/api/tags');
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 2));
      final response = await request.close().timeout(const Duration(seconds: 2));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<List<String>> getInstalledModels() async {
    final baseUrl = await getBaseUrl();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final uri = Uri.parse('$baseUrl/api/tags');
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 3));
      final response = await request.close().timeout(const Duration(seconds: 3));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = await response.transform(utf8.decoder).join();
        final decoded = jsonDecode(body);
        final modelsList = decoded['models'] as List?;
        if (modelsList != null) {
          return modelsList.map((m) => m['name']?.toString() ?? '').where((n) => n.isNotEmpty).toList();
        }
      }
    } catch (_) {} finally {
      client.close(force: true);
    }
    return [
      'qwen3.8',
      'deepseek-v4-flash:cloud',
      'kimi-k3:cloud',
      'ornith-1.5:9b',
      'laguna-xs-2.1',
      'dolphin3',
      'deepcoder',
      'llama3.2',
      'mistral',
      'qwen2.5',
    ];
  }
}
