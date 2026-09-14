import 'package:flutter_test/flutter_test.dart';
import 'package:nex_app/screens/terminal_screen.dart';

void main() {
  group('parseTerminalCommand', () {
    test('parses a simple command', () {
      final parsed = parseTerminalCommand('help');
      expect(parsed.command, 'help');
      expect(parsed.arguments, isEmpty);
    });

    test('parses ai prompts with spaces', () {
      final parsed = parseTerminalCommand('ai tell me about NEX');
      expect(parsed.command, 'ai');
      expect(parsed.arguments, 'tell me about NEX');
    });
  });
}
