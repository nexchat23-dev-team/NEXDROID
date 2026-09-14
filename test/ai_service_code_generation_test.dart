import 'package:flutter_test/flutter_test.dart';
import 'package:nex_app/services/ai_service.dart';
import 'package:nex_app/services/ollama_service.dart';

void main() {
  group('AIService & Ollama Code & Private Script Generation (All Models)', () {
    // New Models Testing
    test('AIService generates Dart/Flutter code with qwen3.8', () async {
      final response = await AIService.instance.chat(
        'Write code for a Flutter animated state controller',
        model: 'qwen3.8',
      );

      expect(response, contains('```'));
      expect(response.toLowerCase(), anyOf(contains('dart'), contains('flutter'), contains('class')));
    });

    test('AIService generates Python scripts with deepseek-v4-flash:cloud', () async {
      final response = await AIService.instance.chat(
        'Write python code for a network scanner',
        model: 'deepseek-v4-flash:cloud',
      );

      expect(response, contains('```python'));
      expect(response, contains('def '));
    });

    test('AIService generates Rust security scripts with ornith-1.5:9b', () async {
      final response = await AIService.instance.chat(
        'Write rust code for root process inspection',
        model: 'ornith-1.5:9b',
      );

      expect(response, contains('```'));
      expect(response.toLowerCase(), anyOf(contains('rust'), contains('fn main'), contains('std::')));
    });

    test('AIService generates private PowerShell automation scripts with laguna-xs-2.1', () async {
      final response = await AIService.instance.chat(
        'Create a private script in PowerShell to monitor background file creation',
        model: 'laguna-xs-2.1',
      );

      expect(response, contains('```powershell'));
      expect(response.toLowerCase(), contains('param('));
    });

    test('AIService generates private Bash shell automation daemons with kimi-k3:cloud', () async {
      final response = await AIService.instance.chat(
        'Generate a private bash script to audit network ports in real-time',
        model: 'kimi-k3:cloud',
      );

      expect(response, contains('```bash'));
      expect(response.toLowerCase(), contains('set -euo pipefail'));
    });

    // Previous Models Testing
    test('AIService generates cyber security diagnostics with dolphin3', () async {
      final response = await AIService.instance.chat(
        'Run cyber security port scan diagnostic',
        model: 'dolphin3',
      );

      expect(response, contains('```bash'));
      expect(response.toLowerCase(), contains('security'));
    });

    test('AIService generates code with deepcoder', () async {
      final response = await AIService.instance.chat(
        'Write code for an asynchronous worker',
        model: 'deepcoder',
      );

      expect(response, contains('```'));
      expect(response.toLowerCase(), anyOf(contains('async'), contains('class'), contains('function')));
    });

    test('AIService generates system architecture insights with llama3.2', () async {
      final response = await AIService.instance.chat(
        'Explain NEX platform architecture and dual-database sync',
        model: 'llama3.2',
      );

      expect(response, contains('NEX PLATFORM ARCHITECTURE'));
      expect(response.toLowerCase(), contains('database'));
    });

    test('AIService calculates math formulas with mistral', () async {
      final response = await AIService.instance.chat(
        'Calculate math formula for exponential growth factor',
        model: 'mistral',
      );

      expect(response, contains('MATHEMATICAL COMPUTATION'));
    });

    test('AIService generates arcade tactics with dolphin-phi', () async {
      final response = await AIService.instance.chat(
        'Give me Cyber Racer 2099 high score secrets and token guide',
        model: 'dolphin-phi',
      );

      expect(response.toLowerCase(), anyOf(contains('racer'), contains('token')));
    });

    test('OllamaService builds valid request payload with code-generation system prompt', () {
      final ollama = OllamaService();
      final payload = ollama.buildRequestBody(
        'Create a binary search function in Python',
        model: 'kimi-k3:cloud',
        systemPrompt: 'You are an expert software engineer.',
      );

      expect(payload['model'], equals('kimi-k3:cloud'));
      expect(payload['stream'], isFalse);
      expect((payload['messages'] as List).length, equals(2));
      expect(payload['messages'][0]['role'], equals('system'));
      expect(payload['messages'][1]['role'], equals('user'));
    });

    test('OllamaService includes all 10 models in installed list', () async {
      final ollama = OllamaService();
      final models = await ollama.getInstalledModels();

      // 5 New Models
      expect(models, contains('qwen3.8'));
      expect(models, contains('deepseek-v4-flash:cloud'));
      expect(models, contains('kimi-k3:cloud'));
      expect(models, contains('ornith-1.5:9b'));
      expect(models, contains('laguna-xs-2.1'));

      // Previous Models
      expect(models, contains('dolphin3'));
      expect(models, contains('deepcoder'));
      expect(models, contains('llama3.2'));
      expect(models, contains('mistral'));
      expect(models, contains('qwen2.5'));
    });
  });
}
