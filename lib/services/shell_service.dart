import 'dart:io';

class ShellCommandResult {
  const ShellCommandResult({
    required this.output,
    required this.exitCode,
  });

  final String output;
  final int exitCode;

  bool get success => exitCode == 0;
}

class ShellService {
  Future<ShellCommandResult> run(String command, {String? workingDirectory}) async {
    try {
      final trimmed = command.trim();
      if (trimmed.isEmpty) {
        return const ShellCommandResult(output: '', exitCode: 0);
      }

      ProcessResult result;
      if (Platform.isWindows) {
        result = await Process.run(
          'powershell',
          ['-NoProfile', '-Command', trimmed],
          workingDirectory: workingDirectory,
          runInShell: true,
        );
      } else {
        result = await Process.run(
          'sh',
          ['-c', trimmed],
          workingDirectory: workingDirectory,
          runInShell: true,
        );
      }

      final out = result.stdout.toString().trim();
      final err = result.stderr.toString().trim();
      final combined = [out, err].where((e) => e.isNotEmpty).join('\n');

      return ShellCommandResult(
        output: combined,
        exitCode: result.exitCode,
      );
    } catch (e) {
      return ShellCommandResult(
        output: 'Command execution error: $e\nEnsure system shell environment is accessible.',
        exitCode: -1,
      );
    }
  }
}
