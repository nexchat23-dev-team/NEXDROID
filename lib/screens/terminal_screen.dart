import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../services/shell_service.dart';
import '../utils/constants.dart';

class TerminalCommand {
  const TerminalCommand(this.command, this.arguments);
  final String command;
  final String arguments;
}

TerminalCommand parseTerminalCommand(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return const TerminalCommand('', '');
  }

  final parts = trimmed.split(RegExp(r'\s+'));
  final command = parts.first.toLowerCase();
  final arguments = trimmed.substring(command.length).trim();

  return TerminalCommand(command, arguments);
}

class TerminalScreen extends StatefulWidget {
  static const routeName = '/terminal';
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen>
    with TickerProviderStateMixin {
  // Output + command state
  final List<Map<String, String>> _output = [];
  final TextEditingController _commandController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _commandHistory = [];

  // Workspace
  late String _workspaceRoot;
  late String _currentPath;

  // Boot
  bool _startupComplete = false;
  bool _typewriterActive = false;
  String _typingBuffer = '';

  // Cursor blink
  bool _showCursor = true;
  Timer? _cursorTimer;

  // Shooting star
  bool _showShootingStar = false;
  double _shootingStartX = 0;
  double _shootingStartY = 0;
  double _shootingEndX = 0;
  double _shootingEndY = 0;
  Color _shootingStarColor = Colors.white;
  Color _shootingFromColor = Colors.white;
  Color _shootingToColor = Colors.white;

  // Matrix rain
  bool _showMatrixRain = false;

  // Telemetry
  double _cpuLoad = 0.22;
  double _ramUsed = 2.1;
  int _uptimeSeconds = 0;
  Timer? _telemetryTimer;

  // Animations
  late AnimationController _pulseController;
  late AnimationController _earthOrbitController;
  late AnimationController _matrixController;
  double _pulseValue = 0;
  double _earthOrbit = 0;

  static const _startupLines = [
    '[ BIOS ] POST check ..................... OK',
    '[ KERN ] Loading NEX kernel v4.2.0 ..... OK',
    '[ CRYPT ] AES-256-GCM engine ........... ONLINE',
    '[ NET  ] Mesh relay handshake .......... STABLE',
    '[ AI   ] Neural core inference ......... READY',
    '[ SYS  ] All subsystems operational',
  ];

  static const _asciiLogo = r'''
 _   _ _______  __
| \ | | ____\ \/ /
|  \| |  _|  \  / 
| |\  | |___ /  \ 
|_| \_|_____/_/\_\
  COMMAND DECK v2.0
''';

  @override
  void initState() {
    super.initState();
    _workspaceRoot = '/data/data/nex/workspace';
    _currentPath = _workspaceRoot;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..addListener(() {
        if (mounted) setState(() => _pulseValue = _pulseController.value);
      })
      ..repeat(reverse: true);

    _earthOrbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..addListener(() {
        if (mounted) setState(() => _earthOrbit = _earthOrbitController.value);
      })
      ..repeat();

    _matrixController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _cursorTimer = Timer.periodic(const Duration(milliseconds: 530), (_) {
      if (mounted) setState(() => _showCursor = !_showCursor);
    });

    // Telemetry updater
    _telemetryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _uptimeSeconds++;
          _cpuLoad = 0.15 + math.Random().nextDouble() * 0.3;
          _ramUsed = 2.0 + math.Random().nextDouble() * 1.5;
        });
      }
    });

    // Shooting star timer
    Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted && _startupComplete) _launchShootingStar();
    });

    _loadWorkspaceState();
    _playStartupSequence();
  }

  @override
  void dispose() {
    _commandController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    _earthOrbitController.dispose();
    _matrixController.dispose();
    _cursorTimer?.cancel();
    _telemetryTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadWorkspaceState() async {
    // Workspace state persistence stub
  }

  Future<void> _persistWorkspaceState() async {
    // Workspace state persistence stub
  }

  void _launchShootingStar() {
    final size = MediaQuery.of(context).size;
    final startX = math.Random().nextDouble() * size.width * 0.7;
    final startY = math.Random().nextDouble() * size.height * 0.16;
    final endX = startX + size.width * 0.35;
    final endY = startY + size.height * 0.12;
    final palette = [
      Colors.white,
      const Color(0xFF7DDCFF),
      const Color(0xFFB23BFF),
      const Color(0xFFFFD166),
    ];

    setState(() {
      _shootingStartX = startX;
      _shootingStartY = startY;
      _shootingEndX = endX;
      _shootingEndY = endY;
      _shootingFromColor = palette[math.Random().nextInt(palette.length)];
      _shootingToColor = palette[math.Random().nextInt(palette.length)];
      _shootingStarColor = _shootingFromColor;
      _showShootingStar = true;
    });
  }

  void _addOutput(String type, String message) {
    if (!mounted) return;
    setState(() {
      _output.add({'type': type, 'message': message});
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _playStartupSequence() async {
    _addOutput('welcome', _asciiLogo);
    _addOutput('welcome', '>>> NEX_TERMINAL_OS [v2.0.0] <<<');
    for (final line in _startupLines) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      _addOutput('live', line);
    }
    setState(() => _startupComplete = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _typewriterActive = true;
      _typingBuffer = 'boot complete • awaiting command';
    });
  }

  Future<void> _runTypewriterEffect(String text) async {
    if (!mounted) return;
    setState(() {
      _typewriterActive = true;
      _typingBuffer = '';
    });

    for (var i = 0; i < text.length; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 20));
      setState(() => _typingBuffer = text.substring(0, i + 1));
    }

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() {
      _typewriterActive = false;
      _typingBuffer = '';
    });
  }

  Future<void> _runCrazyWorkSequence() async {
    final commands = [
      'COMPUTE: DISPATCHING HEURISTIC TASKS...',
      'STREAM: LOGS AGGREGATED FROM NODE_42...',
      'CRYPT: ROTATING PAYLOAD KEYS...',
      'TUNNEL: REACTIVE_PIPELINE_STABLE...',
      'AI_CORE: INFERENCE ENGINE FIRING...',
      'DONE: SESSION LOGGED. TERMINAL REMAINS LIVE.',
    ];

    for (final line in commands) {
      if (!mounted) return;
      _addOutput('live', line);
      await Future.delayed(const Duration(milliseconds: 180));
    }
  }

  Future<void> _runAiPrompt(String prompt) async {
    if (prompt.trim().isEmpty) {
      _addOutput('error', 'ERR: MISSING_AI_PROMPT');
      return;
    }

    _addOutput('info', '┌─ AI NEURAL CORE ─────────────────────┐');
    _addOutput('info', '│ QUERYING NEX AI...                   │');
    try {
      final response = await AIService.instance.chat(prompt.trim());
      _addOutput('success', '│ RESPONSE:                            │');
      _addOutput('live', '│ $response');
      _addOutput('info', '└──────────────────────────────────────┘');
    } catch (error) {
      _addOutput('success', '│ AI_RESPONSE [NEX Core System]:       │');
      _addOutput('live',
          '│ Received query "$prompt". System operating in local cyber-terminal mode. Status: 100% Operational.');
      _addOutput('info', '└──────────────────────────────────────┘');
    }
  }

  Future<void> _runShellCommand(String command) async {
    _addOutput('info', 'RUNNING: $command');
    unawaited(_runTypewriterEffect('EXECUTING :: $command'));
    try {
      final result =
          await ShellService().run(command, workingDirectory: _currentPath);
      if (result.output.trim().isNotEmpty) {
        _addOutput('live', result.output.trim());
      }
      if (result.success) {
        _addOutput('success', 'EXIT_CODE: 0');
      } else {
        _addOutput('error', 'EXIT_CODE: ${result.exitCode}');
      }
    } catch (error) {
      _addOutput('error', 'SHELL_ERROR: $error');
    }
  }

  void _addToHistory(String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return;
    if (_commandHistory.isNotEmpty && _commandHistory.last == trimmed) return;
    _commandHistory.add(trimmed);
  }

  Future<void> _handleCommandSubmit(String raw) async {
    final command = raw.trim();
    if (command.isEmpty) return;

    _addToHistory(command);
    await _executeCommand(command);
    _commandController.clear();
  }

  String _resolvePath(String input) {
    if (input.startsWith('/')) return input;
    return '$_currentPath/$input';
  }

  String _escapeShellArg(String arg) =>
      "'${arg.replaceAll("'", "'\\''")}'";

  Future<void> _executeCommand(String command) async {
    final parsed = parseTerminalCommand(command);
    final cmd = parsed.command;
    final args = parsed.arguments;

    if (cmd.isEmpty) return;

    if (!_startupComplete) {
      _addOutput('warning', 'SYS_BUSY: BOOT_SEQUENCE_IN_PROGRESS');
      return;
    }

    _addOutput('command', '[$_currentPath] $command');

    switch (cmd) {
      case 'help':
        _addOutput('info', '''
SYSTEM ACCESS COMMANDS:
  help          - Display system manifest
  clear         - Wipe terminal buffer
  status        - Diagnostics check
  balance       - Token ledger query
  whoami        - Identity verification
  apps          - List active NEX modules
  goto <screen> - Inter-module navigation
  work          - Execute compute simulation
  ai <prompt>   - Query NEX AI neural core
  ask <prompt>  - Ask questions to the AI assistant
  code <lang>   - Generate production code
  scan <target> - Cyber defense security scan
  decrypt <h>   - Neural crypto hash analyzer
  encrypt <txt> - AES-256-GCM crypto encryptor
  top           - Interactive process monitor
  matrix        - Matrix digital rain simulation
  ollama [url]  - View/update Ollama server endpoint
  syslog        - Raw system log dump
  pwd           - Print working directory
  ls            - List workspace contents
  mkdir <dir>   - Create a directory
  touch <file>  - Create an empty file
  cat <file>    - Print file contents
  rm <path>     - Remove a file or directory
  run <script>  - Execute a shell/python script
  clone <repo>  - Clone a Git repository
  initrepo      - Initialize a Git repository
  gitstatus     - Show Git status
  gitpull       - Pull from Git remote
  gitadd        - Stage all changes
  gitcommit     - Commit staged changes
  alias         - Show shell aliases
  env           - Show environment values
  info          - Show terminal environment info
  workspace     - Show the active workspace path
  echo <text>   - Echo text to the terminal
  uname         - Print kernel identity
  history       - Show recent commands
  logout        - Terminate session
''');
        break;

      case 'clear':
        setState(() => _output.clear());
        _addOutput('info', 'BUFFER_WIPED');
        break;

      case 'work':
        _addOutput('info', 'INITIATING WORKFLOW_ALPHA...');
        unawaited(_runCrazyWorkSequence());
        break;

      case 'ai':
      case 'ask':
      case 'prompt':
        await _runAiPrompt(args);
        break;

      case 'code':
        if (args.isEmpty) {
          _addOutput('error', 'ERR: USAGE: code <language or description>');
        } else {
          await _runAiPrompt('Write code in $args');
        }
        break;

      case 'scan':
        _addOutput('info', 'INITIATING CYBER RECONNAISSANCE...');
        await _runAiPrompt(
            'Security port & vulnerability scan for target: ${args.isEmpty ? "localhost" : args}');
        break;

      case 'decrypt':
        _addOutput('info', 'ATTEMPTING NEURAL HASH REVERSAL...');
        await _runAiPrompt(
            'Decrypt and analyze hash token: ${args.isEmpty ? "0x7F4A99BC" : args}');
        break;

      case 'encrypt':
        await _runEncrypt(args);
        break;

      case 'top':
        _runProcessMonitor();
        break;

      case 'matrix':
        _addOutput('success', 'WAKE UP, NEO... THE MATRIX HAS YOU.');
        _triggerMatrixRain();
        break;

      case 'ollama':
        if (args.isEmpty) {
          final host =
              await AIService.instance.ollamaService.getBaseUrl();
          final online =
              await AIService.instance.ollamaService.isAvailable();
          _addOutput('info', 'OLLAMA_ENDPOINT: $host');
          _addOutput('info',
              'STATUS: ${online ? "ONLINE" : "OFFLINE (NEX Neural Core Active)"}');
        } else {
          await AIService.instance.ollamaService
              .setCustomHost(args.trim());
          final online =
              await AIService.instance.ollamaService.isAvailable();
          _addOutput('success', 'OLLAMA_HOST_UPDATED: ${args.trim()}');
          _addOutput('info',
              'LINK_STATUS: ${online ? "CONNECTED" : "OFFLINE"}');
        }
        break;

      case 'syslog':
        _addOutput('info', 'RAW_LOG_DUMP:');
        _addOutput('live',
            '[${DateTime.now().hour}:17] netflow connected.');
        _addOutput('live',
            '[${DateTime.now().hour}:32] AI_kernel synchronized.');
        _addOutput('live',
            '[${DateTime.now().hour}:01] handshake complete.');
        break;

      case 'status':
        _addOutput('success', 'NEX_DIAGNOSTICS:');
        _addOutput('info', '  • SUPABASE: READY');
        _addOutput('info', '  • AUTH_PROTOCOL: ACTIVE');
        _addOutput('info', '  • DB_SYNC: ONLINE');
        _addOutput('info', '  • TOKENS: VALIDATED');
        _addOutput('info',
            '  • CPU_LOAD: ${(_cpuLoad * 100).toStringAsFixed(1)}%');
        _addOutput('info',
            '  • RAM_USAGE: ${_ramUsed.toStringAsFixed(1)} GB / 8.0 GB');
        _addOutput('info', '  • UPTIME: ${_formatUptime()}');
        break;

      case 'balance':
        _addOutput('success', 'LEDGER_QUERY: 1,250.42 NEX');
        break;

      case 'whoami':
        _addOutput('info', 'IDENTITY: active_user');
        _addOutput('info', 'ACCESS_LVL: STANDARD');
        break;

      case 'apps':
        _addOutput('info', 'ACTIVE_MODULES:');
        _addOutput(
            'info', '  - home, chat, group, calls, bet');
        _addOutput(
            'info', '  - market, profile, ai, terminal');
        _addOutput('info', 'USE: GOTO <MODULE_ID>');
        break;

      case 'goto':
        final parts = args.split(RegExp(r'\s+'));
        if (parts.isNotEmpty && parts.first.isNotEmpty) {
          final screen = parts.first;
          _addOutput('info', 'DIVERTING_TRAFFIC TO: $screen...');
          _navigateToScreen(screen);
        } else {
          _addOutput('error', 'ERR: MISSING_MODULE_ID');
        }
        break;

      case 'pwd':
        _addOutput('info', _currentPath);
        break;

      case 'ls':
        await _runShellCommand('ls -la');
        break;

      case 'mkdir':
        if (args.isEmpty) {
          _addOutput('error', 'ERR: MISSING_PATH');
        } else {
          final target = _resolvePath(args);
          await _runShellCommand(
              'mkdir -p ${_escapeShellArg(target)}');
        }
        break;

      case 'touch':
        if (args.isEmpty) {
          _addOutput('error', 'ERR: MISSING_FILE');
        } else {
          final target = _resolvePath(args);
          await _runShellCommand(
              'touch ${_escapeShellArg(target)}');
        }
        break;

      case 'cat':
        if (args.isEmpty) {
          _addOutput('error', 'ERR: MISSING_FILE');
        } else {
          final target = _resolvePath(args);
          await _runShellCommand(
              'cat ${_escapeShellArg(target)}');
        }
        break;

      case 'rm':
        if (args.isEmpty) {
          _addOutput('error', 'ERR: MISSING_PATH');
        } else {
          final target = _resolvePath(args);
          await _runShellCommand(
              'rm -rf ${_escapeShellArg(target)}');
        }
        break;

      case 'run':
        if (args.isEmpty) {
          _addOutput('error', 'ERR: MISSING_SCRIPT');
        } else {
          final target = _resolvePath(args);
          final lowered = target.toLowerCase();
          if (lowered.endsWith('.py')) {
            await _runShellCommand(
                'python3 ${_escapeShellArg(target)}');
          } else if (lowered.endsWith('.sh')) {
            await _runShellCommand(
                'sh ${_escapeShellArg(target)}');
          } else if (lowered.endsWith('.rs')) {
            await _runShellCommand(
                'rustc ${_escapeShellArg(target)}');
          } else {
            await _runShellCommand(
                'sh ${_escapeShellArg(target)}');
          }
        }
        break;

      case 'clone':
        if (args.isEmpty) {
          _addOutput('error', 'ERR: MISSING_REPOSITORY');
        } else {
          await _runShellCommand(
              'git clone ${_escapeShellArg(args)}');
        }
        break;

      case 'initrepo':
        await _runShellCommand('git init');
        break;

      case 'gitstatus':
        await _runShellCommand('git status --short');
        break;

      case 'gitpull':
        await _runShellCommand('git pull');
        break;

      case 'gitadd':
        await _runShellCommand('git add .');
        break;

      case 'gitcommit':
        if (args.isEmpty) {
          _addOutput('error', 'ERR: MISSING_COMMIT_MESSAGE');
        } else {
          await _runShellCommand(
              'git commit -m ${_escapeShellArg(args)}');
        }
        break;

      case 'alias':
        _addOutput('info',
            'aliases: ll=ls -la, gs=git status, ga=git add .');
        break;

      case 'env':
        _addOutput('info', 'TERM=NEX_TERMINAL');
        _addOutput('info', 'SHELL=nex-shell');
        _addOutput('info',
            'PATH=/data/data/nex/workspace:/usr/bin:/bin');
        break;

      case 'info':
        _addOutput('info', 'NEX_TERMINAL_OS 2.0.0');
        _addOutput('info', 'WORKSPACE_ROOT: $_workspaceRoot');
        _addOutput('info', 'CURRENT_PATH: $_currentPath');
        _addOutput('info', 'STARTUP_COMPLETE: $_startupComplete');
        _addOutput('info', 'UPTIME: ${_formatUptime()}');
        break;

      case 'workspace':
        _addOutput('info', 'WORKSPACE_ROOT: $_workspaceRoot');
        _addOutput('info', 'CURRENT_PATH: $_currentPath');
        break;

      case 'echo':
        _addOutput('info', args.isEmpty ? '' : args);
        break;

      case 'uname':
        _addOutput('info', 'Linux NEX-TERM 2.0');
        break;

      case 'history':
        if (_commandHistory.isEmpty) {
          _addOutput('info', 'NO_COMMAND_HISTORY');
        } else {
          for (var i = 0; i < _commandHistory.length; i++) {
            _addOutput(
                'info', '${i + 1}  ${_commandHistory[i]}');
          }
        }
        break;

      case 'git':
      case 'python':
      case 'python3':
      case 'cargo':
      case 'pip':
      case 'pip3':
      case 'apt':
      case 'pkg':
      case 'bash':
      case 'sh':
      case 'rustc':
      case 'rustup':
      case 'curl':
      case 'wget':
      case 'node':
      case 'npm':
      case 'yarn':
        await _runShellCommand(command);
        break;

      case 'cd':
        if (args.isEmpty || args == '~' || args == '/') {
          setState(() => _currentPath = _workspaceRoot);
          await _persistWorkspaceState();
          _addOutput('info', _currentPath);
        } else if (args == '..') {
          final next =
              _currentPath.replaceFirst(RegExp(r'/[^/]+$'), '');
          setState(
              () => _currentPath = next.isEmpty ? '/' : next);
          await _persistWorkspaceState();
          _addOutput('info', _currentPath);
        } else {
          final target = _resolvePath(args);
          setState(() => _currentPath = target);
          await _persistWorkspaceState();
          _addOutput('info', _currentPath);
        }
        break;

      case 'logout':
        _addOutput('warning', 'SESSION_TERMINATED.');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
        break;

      default:
        await _runShellCommand(command);
        break;
    }
  }

  // ── New commands ──────────────────────────────────────────────────────
  Future<void> _runEncrypt(String text) async {
    if (text.isEmpty) {
      _addOutput('error', 'ERR: USAGE: encrypt <text>');
      return;
    }

    _addOutput('info', 'ENCRYPTING...');
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _addOutput('info', '  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ 100%');

    // Generate fake encrypted hex
    final rng = math.Random();
    final hexBytes = List.generate(
        32, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'));
    final hexStr = hexBytes.join('');

    _addOutput('success', '┌─ ENCRYPTED OUTPUT ─────────────────────┐');
    _addOutput('live', '│ ALGORITHM: AES-256-GCM                 │');
    _addOutput('live', '│ TIMESTAMP: ${DateTime.now().toIso8601String()}');
    _addOutput('live', '│ INPUT: "$text"');
    _addOutput('success', '│ CIPHER: 0x$hexStr');
    _addOutput('success', '└────────────────────────────────────────┘');
  }

  void _runProcessMonitor() {
    final rng = math.Random();
    final processes = [
      {'pid': '1', 'name': 'nex_kernel', 'status': 'RUNNING'},
      {'pid': '12', 'name': 'ai_core', 'status': 'RUNNING'},
      {'pid': '34', 'name': 'mesh_relay', 'status': 'RUNNING'},
      {'pid': '56', 'name': 'crypto_vault', 'status': 'SLEEPING'},
      {'pid': '78', 'name': 'db_sync', 'status': 'RUNNING'},
      {'pid': '91', 'name': 'auth_daemon', 'status': 'RUNNING'},
      {'pid': '103', 'name': 'log_aggregator', 'status': 'SLEEPING'},
      {'pid': '142', 'name': 'threat_scanner', 'status': 'RUNNING'},
      {'pid': '199', 'name': 'zombie_proc', 'status': 'ZOMBIE'},
      {'pid': '201', 'name': 'ui_renderer', 'status': 'RUNNING'},
    ];

    _addOutput('success',
        '┌─ PROCESS MONITOR ──────────────────────────────────┐');
    _addOutput('info',
        '│ PID    PROCESS            CPU%    MEM%    STATUS   │');
    _addOutput('info',
        '│──────────────────────────────────────────────────── │');

    for (final p in processes) {
      final cpu = (rng.nextDouble() * 45).toStringAsFixed(1).padLeft(5);
      final mem = (rng.nextDouble() * 30).toStringAsFixed(1).padLeft(5);
      final pid = p['pid']!.padRight(6);
      final name = p['name']!.padRight(18);
      final status = p['status']!;
      _addOutput(
        status == 'ZOMBIE' ? 'error' : (status == 'SLEEPING' ? 'info' : 'live'),
        '│ $pid $name $cpu   $mem   $status',
      );
    }

    _addOutput('success',
        '└────────────────────────────────────────────────────┘');
  }

  void _triggerMatrixRain() {
    setState(() => _showMatrixRain = true);
    _matrixController.forward(from: 0);
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showMatrixRain = false);
    });
  }

  String _formatUptime() {
    final h = _uptimeSeconds ~/ 3600;
    final m = (_uptimeSeconds % 3600) ~/ 60;
    final s = _uptimeSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _navigateToScreen(String screen) {
    final routes = {
      'home': '/home',
      'chat': '/chat',
      'group': '/group',
      'calls': '/calls',
      'bet': '/betting',
      'market': '/marketplace',
      'profile': '/profile',
      'settings': '/settings',
      'ai': '/ai-chat',
      'terminal': '/terminal',
    };

    final route = routes[screen];
    if (route != null) {
      if (!mounted) return;
      Navigator.pushNamed(context, route);
    } else {
      _addOutput('error', 'ERR: MODULE_NOT_FOUND "$screen"');
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'command':
        return kNeonBlue;
      case 'success':
        return kNeonGreen;
      case 'error':
        return Colors.redAccent;
      case 'warning':
        return Colors.amber;
      case 'live':
        return Colors.lightGreenAccent.withValues(alpha: 0.7);
      case 'info':
        return kNeonBlue.withValues(alpha: 0.8);
      case 'welcome':
        return kNeonBlue;
      default:
        return Colors.white60;
    }
  }

  // Quick command buttons
  static const _quickCommands = [
    {'cmd': 'status', 'icon': 'diagnostics', 'label': 'STATUS'},
    {'cmd': 'whoami', 'icon': 'person', 'label': 'WHOAMI'},
    {'cmd': 'apps', 'icon': 'apps', 'label': 'APPS'},
    {'cmd': 'syslog', 'icon': 'log', 'label': 'SYSLOG'},
    {'cmd': 'history', 'icon': 'history', 'label': 'HISTORY'},
    {'cmd': 'top', 'icon': 'monitor', 'label': 'TOP'},
    {'cmd': 'matrix', 'icon': 'matrix', 'label': 'MATRIX'},
    {'cmd': 'scan localhost', 'icon': 'scan', 'label': 'SCAN'},
    {'cmd': 'work', 'icon': 'work', 'label': 'WORK'},
  ];

  IconData _quickIcon(String key) {
    switch (key) {
      case 'diagnostics':
        return Icons.monitor_heart_rounded;
      case 'person':
        return Icons.person_rounded;
      case 'apps':
        return Icons.apps_rounded;
      case 'log':
        return Icons.receipt_long_rounded;
      case 'history':
        return Icons.history_rounded;
      case 'monitor':
        return Icons.table_chart_rounded;
      case 'matrix':
        return Icons.grid_on_rounded;
      case 'scan':
        return Icons.radar_rounded;
      case 'work':
        return Icons.engineering_rounded;
      default:
        return Icons.terminal_rounded;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A111F),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [kNeonBlue, Color(0xFF3B82F6)]),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                      color: kNeonBlue.withValues(alpha: 0.3),
                      blurRadius: 10),
                ],
              ),
              child: const Icon(Icons.terminal_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 14),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NEX_COMMAND_DECK',
                    style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 1)),
                Text('QUANTUM TERMINAL v2.0',
                    style: TextStyle(
                        color: Colors.white30,
                        fontFamily: 'monospace',
                        fontSize: 8,
                        letterSpacing: 1.5)),
              ],
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: kNeonBlue, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.layers_clear_rounded,
                color: kNeonBlue, size: 20),
            onPressed: () {
              setState(() => _output.clear());
              _addOutput('info', 'BUFFER_CLEARED');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          Column(
            children: [
              // Telemetry strip
              _buildTelemetryStrip(),
              // Output area
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF070B14),
                    border: Border(
                        top: BorderSide(color: Colors.white10)),
                  ),
                  child: Stack(
                    children: [
                      // CRT effect
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _CRTPhosphorPainter(
                                flicker: _pulseValue),
                          ),
                        ),
                      ),
                      ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 20),
                        itemCount: _output.length,
                        itemBuilder: (context, index) {
                          final item = _output[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: SelectableText(
                              item['message']!,
                              style: TextStyle(
                                color: _getTypeColor(
                                    item['type']!),
                                fontSize: 11,
                                fontFamily: 'monospace',
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                                shadows: [
                                  Shadow(
                                    color: _getTypeColor(
                                            item['type']!)
                                        .withValues(alpha: 0.3),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              // Quick command bar
              _buildQuickCommandBar(),
              // Input
              _buildInputBar(),
            ],
          ),
          _buildShootingStarOverlay(),
          if (_showMatrixRain) _buildMatrixRainOverlay(),
        ],
      ),
    );
  }

  // ── Telemetry Strip ─────────────────────────────────────────────────────
  Widget _buildTelemetryStrip() {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A111F),
        border: Border(
          bottom: BorderSide(
              color: kNeonBlue.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          // CPU
          _telemetryBar('CPU',
              _cpuLoad, _cpuLoad > 0.7 ? Colors.redAccent : kNeonGreen),
          const SizedBox(width: 16),
          // RAM
          _telemetryBar('RAM', _ramUsed / 8.0, kNeonBlue),
          const SizedBox(width: 10),
          Text('${_ramUsed.toStringAsFixed(1)}/8.0G',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 8,
                  fontFamily: 'monospace')),
          const Spacer(),
          // Network
          Icon(Icons.wifi_rounded,
              color: kNeonGreen.withValues(alpha: 0.5), size: 12),
          const SizedBox(width: 4),
          Text('STABLE',
              style: TextStyle(
                  color: kNeonGreen.withValues(alpha: 0.5),
                  fontSize: 8,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 14),
          // Uptime
          Icon(Icons.timer_outlined,
              color: Colors.white.withValues(alpha: 0.3), size: 12),
          const SizedBox(width: 4),
          Text(_formatUptime(),
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 8,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _telemetryBar(String label, double value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 8,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w800)),
        const SizedBox(width: 6),
        SizedBox(
          width: 50,
          height: 6,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text('${(value * 100).toStringAsFixed(0)}%',
            style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 8,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  // ── Quick Command Bar ───────────────────────────────────────────────────
  Widget _buildQuickCommandBar() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFF0A111F),
        border: Border(
          top: BorderSide(
              color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        itemCount: _quickCommands.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final q = _quickCommands[i];
          return GestureDetector(
            onTap: () => _handleCommandSubmit(q['cmd']!),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: kNeonBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: kNeonBlue.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_quickIcon(q['icon']!),
                      color: kNeonBlue.withValues(alpha: 0.7),
                      size: 12),
                  const SizedBox(width: 4),
                  Text(q['label']!,
                      style: TextStyle(
                          color: kNeonBlue.withValues(alpha: 0.8),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Input Bar ───────────────────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
      decoration: BoxDecoration(
        color: const Color(0xFF0A111F),
        border: Border(
            top: BorderSide(
                color: kNeonBlue.withValues(alpha: 0.2))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            const Text('\$ ',
                style: TextStyle(
                    color: kNeonBlue,
                    fontSize: 16,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900)),
            if (_typewriterActive)
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: kNeonBlue.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: kNeonBlue.withValues(alpha: 0.25)),
                ),
                child: Text(
                  _typingBuffer,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            Expanded(
              child: TextField(
                controller: _commandController,
                enabled: _startupComplete,
                style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 14),
                cursorColor: kNeonBlue,
                decoration: InputDecoration(
                  hintText: _startupComplete
                      ? 'Awaiting command...'
                      : 'SYS_BOOTING...',
                  hintStyle:
                      const TextStyle(color: Colors.white12),
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.send,
                enableSuggestions: false,
                autocorrect: false,
                onSubmitted: (value) async {
                  await _handleCommandSubmit(value);
                },
              ),
            ),
            if (_startupComplete)
              Opacity(
                opacity: _showCursor ? 1.0 : 0.0,
                child: Container(
                    width: 8,
                    height: 18,
                    color: kNeonBlue.withValues(alpha: 0.8)),
              ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () async {
                await _handleCommandSubmit(
                    _commandController.text);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kNeonBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: kNeonBlue.withValues(alpha: 0.3)),
                ),
                child: const Icon(
                    Icons.subdirectory_arrow_left_rounded,
                    color: kNeonBlue,
                    size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Animated Background ─────────────────────────────────────────────────
  Widget _buildAnimatedBackground() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 700),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0F172A).withValues(alpha: 0.92),
                    const Color(0xFF070B14),
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0.85,
                child: CustomPaint(
                  painter:
                      _TerminalSpacefieldPainter(_earthOrbit),
                ),
              ),
            ),
            // Earth
            Positioned(
              right: 24,
              top: 42,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: kNeonBlue.withValues(alpha: 0.22),
                      blurRadius: 26,
                    ),
                  ],
                  gradient: const RadialGradient(
                    colors: [
                      Color(0xFF4FD1C5),
                      Color(0xFF0F3D5E),
                    ],
                    center: Alignment(-0.2, -0.2),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Transform.rotate(
                        angle: _earthOrbit * 6.28,
                        child: CustomPaint(
                          painter: _OrbitalRingPainter(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shooting Star ───────────────────────────────────────────────────────
  Widget _buildShootingStarOverlay() {
    if (!_showShootingStar) return const SizedBox.shrink();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        final x = _shootingStartX +
            (_shootingEndX - _shootingStartX) * value;
        final y = _shootingStartY +
            (_shootingEndY - _shootingStartY) * value;
        final opacity =
            (1 - value).clamp(0.0, 1.0).toDouble();
        final currentColor =
            Color.lerp(_shootingFromColor, _shootingToColor, value) ??
                _shootingStarColor;

        return Positioned(
          left: x,
          top: y,
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: -0.35,
              child: Container(
                width: 140,
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      currentColor.withValues(alpha: 0.95),
                      _shootingToColor.withValues(alpha: 0.6),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          currentColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      onEnd: () =>
          setState(() => _showShootingStar = false),
    );
  }

  // ── Matrix Rain Overlay ─────────────────────────────────────────────────
  Widget _buildMatrixRainOverlay() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _matrixController,
        builder: (context, _) => Container(
          color: Colors.black.withValues(alpha: 0.85),
          child: Stack(
            children: [
              CustomPaint(
                size: Size.infinite,
                painter: _MatrixRainPainter(
                    progress: _matrixController.value),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('WAKE UP, NEO...',
                        style: TextStyle(
                            color: kNeonGreen.withValues(alpha: 0.9),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            letterSpacing: 3,
                            shadows: const [
                              Shadow(
                                  color: kNeonGreen,
                                  blurRadius: 20),
                            ])),
                    const SizedBox(height: 8),
                    Text('THE MATRIX HAS YOU',
                        style: TextStyle(
                            color: kNeonGreen.withValues(alpha: 0.5),
                            fontSize: 12,
                            fontFamily: 'monospace',
                            letterSpacing: 2)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CRT PHOSPHOR PAINTER
// ════════════════════════════════════════════════════════════════════════════
class _CRTPhosphorPainter extends CustomPainter {
  _CRTPhosphorPainter({required this.flicker});
  final double flicker;

  @override
  void paint(Canvas canvas, Size size) {
    // Scanlines with variable opacity
    final scanPaint = Paint();
    for (var y = 0.0; y < size.height; y += 3) {
      final alpha = 0.04 + (y % 6 == 0 ? 0.03 : 0);
      scanPaint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), scanPaint);
    }

    // Vignette effect at edges
    final vignettePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.3 + flicker * 0.05),
        ],
        stops: const [0.6, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), vignettePaint);
  }

  @override
  bool shouldRepaint(covariant _CRTPhosphorPainter oldDelegate) =>
      (oldDelegate.flicker - flicker).abs() > 0.1;
}

// ════════════════════════════════════════════════════════════════════════════
// MATRIX RAIN PAINTER
// ════════════════════════════════════════════════════════════════════════════
class _MatrixRainPainter extends CustomPainter {
  _MatrixRainPainter({required this.progress});
  final double progress;

  static const _chars = 'アイウエオカキクケコサシスセソタチツテトナニヌネノ0123456789ABCDEF';

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    const colWidth = 14.0;
    final cols = (size.width / colWidth).ceil();

    for (var c = 0; c < cols; c++) {
      final speed = 0.5 + rng.nextDouble() * 1.5;
      final offset = rng.nextDouble() * size.height;
      final colLen = 8 + rng.nextInt(20);

      for (var r = 0; r < colLen; r++) {
        final y = (offset + r * 16 + progress * speed * size.height) %
            (size.height + 200) -
            100;
        final alpha = (1 - r / colLen).clamp(0.0, 1.0) * 0.7;
        final charIdx = (c * 7 + r * 13 + (progress * 50).toInt()) %
            _chars.length;

        final textSpan = TextSpan(
          text: _chars[charIdx],
          style: TextStyle(
            color: (r == 0
                    ? Colors.white
                    : const Color(0xFF00FF41))
                .withValues(alpha: alpha),
            fontSize: 12,
            fontFamily: 'monospace',
            fontWeight: r == 0 ? FontWeight.w900 : FontWeight.w400,
          ),
        );
        final tp = TextPainter(
            text: textSpan, textDirection: TextDirection.ltr);
        tp.layout();
        tp.paint(canvas, Offset(c * colWidth, y));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MatrixRainPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ════════════════════════════════════════════════════════════════════════════
// SPACEFIELD PAINTER
// ════════════════════════════════════════════════════════════════════════════
class _TerminalSpacefieldPainter extends CustomPainter {
  const _TerminalSpacefieldPainter(this.orbit);
  final double orbit;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.9);

    // Stars
    for (var i = 0; i < 150; i++) {
      final x = (i * 29) % size.width;
      final y = ((i * 37) % 700) / 700 * size.height;
      final alpha =
          0.25 + ((x + y + orbit * size.width) % 20) / 40;
      canvas.drawCircle(
          Offset(x, y),
          1.0 + (alpha * 0.7),
          paint
            ..color = Colors.white.withValues(
                alpha: alpha.clamp(0.2, 1.0)));
    }

    // Nebula glow
    final nebulaPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.5, 0.3),
        radius: 0.8,
        colors: [
          const Color(0xFF8B5CF6).withValues(alpha: 0.04),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), nebulaPaint);

    // Horizon glow line
    final path = Path();
    path.moveTo(0, size.height * 0.82);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.62,
        size.width * 0.5, size.height * 0.78);
    path.quadraticBezierTo(size.width * 0.75, size.height * 0.94,
        size.width, size.height * 0.72);
    final glowPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          kNeonBlue.withValues(alpha: 0.35),
          Colors.transparent,
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(
        path,
        glowPaint
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _TerminalSpacefieldPainter oldDelegate) =>
      oldDelegate.orbit != orbit;
}

// ════════════════════════════════════════════════════════════════════════════
// ORBITAL RING PAINTER
// ════════════════════════════════════════════════════════════════════════════
class _OrbitalRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: 0.55);

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.3,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.42,
      paint..color = kNeonBlue.withValues(alpha: 0.35),
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.52,
      paint
        ..color = Colors.purpleAccent.withValues(alpha: 0.26),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
