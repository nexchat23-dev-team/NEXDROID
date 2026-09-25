import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GeminiKeyInfo {
  final String key;
  final int index;
  const GeminiKeyInfo({required this.key, required this.index});
}

/// Google Gemini API Multi-Key Pool & Failover Service
/// Direct port of NEXCHAT's `gemini-config.js` and `chronex-ai-service.js`.
/// Provides round-robin key rotation, rate-limit (429/503) cooldowns,
/// fallback model cascading, and multi-turn conversational context.
class GeminiService {
  GeminiService._() {
    _initKeys();
    loadCustomKeys();
  }
  static final GeminiService instance = GeminiService._();

  // Safe base64-encoded key store identical to NEXCHAT gemini-config.js
  static const List<String> _encodedKeys = [
    'QVEuQWI4Uk42SkM1Q2NaTDAtZXgxbUtuUEpzYk9NcHdXcUYtODFXbVFMWUtQNF83VS04Z3c=',
    'QVEuQWI4Uk42SWwxdXNzb1R1Wkd6b0NXXWRQemhEbFNfM2JjcW4zSTAxTi03c0p0QmZoR3c=',
    'QVEuQWI4Uk42TGhkb21vTG5DYjRUcmFoREVhWm5GczBVbEtTSFVHMHpXRUZwVEhBcFZNZWc=',
    'QVEuQWI4Uk42SVoxUGxHZ1VSSVA0M3p5YTJhTEJkN040YnBsMzVRUmptbnYtaUZJd3R5UUE=',
    'QVEuQWI4Uk42TDRCajh1TEpRYUVCaGJZOHFWU2lLRTVSMWhwVUxkclNlNm5GVzBJb1Q1Vmc=',
    'QVEuQWI4Uk42SXlhcGhSSVhicXFnNFNQMUFhUWlubHhMMlVOR1JtdEF0WS16eXpKSnYxVnc='
  ];

  static const List<String> defaultModels = [
    'gemini-flash-lite-latest',
    'gemini-flash-latest',
    'gemini-pro-latest',
  ];

  static const String defaultSystemInstruction = '''
You are CHRONEX AI, the advanced AI assistant created by NEXCHAT.
You are an expert full-stack developer, mathematician, distributed systems architect, and cybersecurity analyst.
Your core traits:
- Provide clean, accurate, modern code with explanations.
- Solve math, algorithmic, and logic questions with step-by-step clarity.
- Keep responses friendly, sharp, concise, and formatted in clean Markdown.
- Uphold safe and ethical computing practices.
''';

  List<String> _keys = [];
  int _currentIndex = 0;
  final Map<String, int> _cooldowns = {};

  void _initKeys() {
    _keys = _encodedKeys.map((encoded) {
      try {
        return utf8.decode(base64Decode(encoded));
      } catch (e) {
        return encoded;
      }
    }).toList();
  }

  Future<void> loadCustomKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final custom = prefs.getStringList('gemini_custom_keys');
      if (custom != null && custom.isNotEmpty) {
        final valid = custom.where((k) => k.trim().isNotEmpty).toList();
        if (valid.isNotEmpty) {
          for (final vk in valid) {
            if (!_keys.contains(vk)) {
              _keys.insert(0, vk);
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> addCustomKey(String key) async {
    final clean = key.trim();
    if (clean.isEmpty) return;
    if (!_keys.contains(clean)) {
      _keys.insert(0, clean);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('gemini_custom_keys', _keys);
      } catch (_) {}
    }
  }

  int get totalKeys => _keys.length;

  bool isAvailable() => _keys.isNotEmpty;

  GeminiKeyInfo? getNextKey() {
    if (_keys.isEmpty) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    final total = _keys.length;

    for (int i = 0; i < total; i++) {
      final idx = (_currentIndex + i) % total;
      final k = _keys[idx];
      final expiry = _cooldowns[k] ?? 0;
      if (now >= expiry) {
        _currentIndex = (idx + 1) % total;
        return GeminiKeyInfo(key: k, index: idx);
      }
    }

    // All on cooldown, pick earliest expiring
    String earliestKey = _keys[0];
    int earliestExpiry = _cooldowns[earliestKey] ?? 0;
    for (int i = 1; i < total; i++) {
      final k = _keys[i];
      final exp = _cooldowns[k] ?? 0;
      if (exp < earliestExpiry) {
        earliestExpiry = exp;
        earliestKey = k;
      }
    }
    return GeminiKeyInfo(key: earliestKey, index: _keys.indexOf(earliestKey));
  }

  void markCooldown(String key, {int durationMs = 60000}) {
    _cooldowns[key] = DateTime.now().millisecondsSinceEpoch + durationMs;
    if (kDebugMode) {
      final shortKey = key.length > 8 ? '${key.substring(0, 8)}...' : key;
      debugPrint('[GeminiService] Key $shortKey cooled down for ${durationMs ~/ 1000}s');
    }
  }

  void reportSuccess(String key) {
    _cooldowns.remove(key);
  }

  /// Sends a prompt to Google Gemini API using NEXCHAT's multi-key pool
  Future<String?> generateContent(
    String prompt, {
    String? model,
    String? systemInstruction,
    List<Map<String, dynamic>>? conversationHistory,
  }) async {
    final cleanPrompt = prompt.trim();
    if (cleanPrompt.isEmpty) return null;

    final targetModels = (model != null && model.isNotEmpty && model.startsWith('gemini'))
        ? [model, ...defaultModels.where((m) => m != model)]
        : defaultModels;

    // Build payload
    final contents = <Map<String, dynamic>>[];
    if (conversationHistory != null && conversationHistory.isNotEmpty) {
      final recent = conversationHistory.length > 10
          ? conversationHistory.sublist(conversationHistory.length - 10)
          : conversationHistory;
      for (final msg in recent) {
        final role = (msg['role'] == 'assistant' || msg['role'] == 'model') ? 'model' : 'user';
        final text = msg['content']?.toString() ?? '';
        if (text.isNotEmpty) {
          contents.add({
            'role': role,
            'parts': [
              {'text': text}
            ]
          });
        }
      }
    }

    contents.add({
      'role': 'user',
      'parts': [
        {'text': cleanPrompt}
      ]
    });

    final payload = {
      'contents': contents,
      'systemInstruction': {
        'parts': [
          {'text': systemInstruction ?? defaultSystemInstruction}
        ]
      },
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 2048,
        'topP': 0.95,
      }
    };

    final bodyJson = jsonEncode(payload);

    // Multi-key failover loop
    final attempts = _keys.length;
    for (int attempt = 0; attempt < attempts; attempt++) {
      final keyInfo = getNextKey();
      if (keyInfo == null) break;
      final key = keyInfo.key;

      for (final mod in targetModels) {
        try {
          final uri = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$mod:generateContent?key=$key',
          );

          final response = await http
              .post(
                uri,
                headers: {'Content-Type': 'application/json'},
                body: bodyJson,
              )
              .timeout(const Duration(seconds: 15));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final candidates = data['candidates'] as List<dynamic>?;
            if (candidates != null && candidates.isNotEmpty) {
              final candidate = candidates[0] as Map<String, dynamic>;
              final content = candidate['content'] as Map<String, dynamic>?;
              final parts = content?['parts'] as List<dynamic>?;
              if (parts != null && parts.isNotEmpty) {
                final text = parts[0]['text']?.toString();
                if (text != null && text.isNotEmpty) {
                  reportSuccess(key);
                  if (kDebugMode) {
                    debugPrint('[GeminiService] Response OK with model $mod (Key #${keyInfo.index + 1})');
                  }
                  return text.trim();
                }
              }
            }
          }

          final status = response.statusCode;
          if (kDebugMode) {
            debugPrint('[GeminiService] HTTP $status with model $mod (Key #${keyInfo.index + 1})');
          }

          if (status == 429 || status == 503) {
            markCooldown(key, durationMs: 60000);
            break; // Break model loop, try next key
          } else if (status == 404) {
            continue; // Model not found on this endpoint, try next model
          } else {
            // Bad request or unauthorized, try next key
            break;
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[GeminiService] Error with model $mod: $e');
          }
          break; // Try next key
        }
      }
    }

    return null;
  }

  Future<bool> testConnection() async {
    try {
      final testRes = await generateContent('Ping', model: 'gemini-flash-lite-latest');
      return testRes != null && testRes.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
