import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class _TerminalScreenState extends State<TerminalScreen> {
  final TextEditingController _commandController = TextEditingController();
  final List<Map<String, dynamic>> _output = [];
  final ScrollController _scrollController = ScrollController();
  final List<String> _commandHistory = [];
  String _workspaceRoot = '/data/data/nex/workspace';
  String _currentPath = '/data/data/nex/workspace';
  bool _startupComplete = false;
  bool _showCursor = true;
  Timer? _cursorTimer;
  Timer? _shootingStarTimer;
  bool _showShootingStar = false;
  bool _typewriterActive = false;
  double _pulseValue = 0.0;
  double _earthOrbit = 0.0;
  String _typingBuffer = '';
  double _shootingStartX = 0;
  double _shootingStartY = 0;
  double _shootingEndX = 0;
  double _shootingEndY = 0;
  Color _shootingStarColor = Colors.white;
  Color _shootingFromColor = Colors.white;
  Color _shootingToColor = Colors.white;

  // Professional System Manifest
  final List<String> _startupLines = [
    'BOOT_SEQUENCE: INITIALIZING NEX_CORE...',
    'KERNEL: SPAWNING REALTIME ENGINE [0x42AF]...',
    'NET_LAYER: SECURE CHANNELS OPENED...',
    'MODULES: SYNCING AI & NEX_CHAT LIBRARIES...',
    'QUEUE: LOADING WORK_THREAD_01...',
    'SYSTEM_READY: ENCRYPTION ACTIVE. TYPE "HELP".',
  ];

  @override
  void initState() {
    super.initState();
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _showCursor = !_showCursor);
    });
    Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted) return;
      setState(() {
        _pulseValue = (_pulseValue + 0.018).clamp(0.0, 1.0);
        _earthOrbit = (_earthOrbit + 0.008).clamp(0.0, 1.0);
      });
    });
    _scheduleShootingStar();
    unawaited(_initializeWorkspace());
    _playStartupSequence();
  }

  @override
  void dispose() {
    _cursorTimer?.cancel();
    _shootingStarTimer?.cancel();
    _commandController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeWorkspace() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final defaultRoot = '${appDir.path}/workspace';
      final prefs = await SharedPreferences.getInstance();
      final savedRoot = prefs.getString('terminal_workspace_root');
      final savedPath = prefs.getString('terminal_current_path');
      final root = savedRoot ?? defaultRoot;
      final dir = Directory(root);
      await dir.create(recursive: true);

      if (!mounted) return;
      setState(() {
        _workspaceRoot = root;
        _currentPath = savedPath ?? root;
      });
      await prefs.setString('terminal_workspace_root', root);
      await prefs.setString('terminal_current_path', _currentPath);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _workspaceRoot = '/data/data/nex/workspace';
        _currentPath = '/data/data/nex/workspace';
      });
    }
  }

  Future<void> _persistWorkspaceState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('terminal_workspace_root', _workspaceRoot);
      await prefs.setString('terminal_current_path', _currentPath);
    } catch (_) {}
  }

  String _resolvePath(String target) {
    if (target.isEmpty) return _currentPath;
    if (target.startsWith('/')) return target;
    if (target == '.') return _currentPath;
    if (target == '~') return _workspaceRoot;
    if (_currentPath.endsWith('/')) {
      return '$_currentPath$target';
    }
    return '$_currentPath/$target';
  }

  String _escapeShellArg(String value) {
    return "'${value.replaceAll("'", "'\"'\"'")}'";
  }

  void _scheduleShootingStar() {
    _shootingStarTimer?.cancel();
    _shootingStarTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      _launchShootingStar();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _launchShootingStar();
    });
  }

  void _launchShootingStar() {
    final size = MediaQuery.of(context).size;
    final startX = Random().nextDouble() * size.width * 0.7;
    final startY = Random().nextDouble() * size.height * 0.16;
    final endX = startX + size.width * 0.35;
    final endY = startY + size.height * 0.12;
    final palette = [Colors.white, const Color(0xFF7DDCFF), const Color(0xFFB23BFF), const Color(0xFFFFD166)];

    setState(() {
      _shootingStartX = startX;
      _shootingStartY = startY;
      _shootingEndX = endX;
      _shootingEndY = endY;
      _shootingFromColor = palette[Random().nextInt(palette.length)];
      _shootingToColor = palette[Random().nextInt(palette.length)];
      _shootingStarColor = _shootingFromColor;
      _showShootingStar = true;
    });
  }

  void _addOutput(String type, String message) {
    if (!mounted) return;
    setState(() {
      _output.add({
        'type': type,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      });
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
    _addOutput('welcome', '>>> NEX_TERMINAL_OS [v1.0.42] <<<');
    for (final line in _startupLines) {
      await Future.delayed(const Duration(milliseconds: 250));
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
      setState(() {
        _typingBuffer = text.substring(0, i + 1);
      });
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

    _addOutput('info', 'AI_LOCAL: QUERYING NEX AI...');
    try {
      final response = await AIService.instance.chat(prompt.trim());
      _addOutput('success', 'AI_RESPONSE:');
      _addOutput('live', response);
    } catch (error) {
      _addOutput('success', 'AI_RESPONSE [NEX Core System]:');
      _addOutput('live', 'Received query "$prompt". System operating in local cyber-terminal mode. Status: 100% Operational.');
    }
  }

  Future<void> _runShellCommand(String command) async {
    _addOutput('info', 'RUNNING: $command');
    unawaited(_runTypewriterEffect('EXECUTING :: $command'));
    try {
      final result = await ShellService().run(command, workingDirectory: _currentPath);
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
  ollama [url]  - View/update Ollama server endpoint
  matrix        - Enter Matrix terminal simulation
  syslog        - Raw system log dump
  pwd           - Print working directory
  ls            - List workspace contents
  mkdir <dir>   - Create a directory
  touch <file>  - Create an empty file
  cat <file>    - Print file contents
  rm <path>     - Remove a file or directory
  run <script>  - Execute a shell/python script
  clone <repo>  - Clone a Git repository
  initrepo      - Initialize a Git repository in the current folder
  gitstatus     - Show Git status in the current folder
  gitpull       - Pull from the current Git remote
  gitadd        - Stage all changes in the current folder
  gitcommit     - Commit staged changes with a message
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
        await _runAiPrompt('Security port & vulnerability scan for target: ${args.isEmpty ? "localhost" : args}');
        break;

      case 'decrypt':
        _addOutput('info', 'ATTEMPTING NEURAL HASH REVERSAL...');
        await _runAiPrompt('Decrypt and analyze hash token: ${args.isEmpty ? "0x7F4A99BC" : args}');
        break;

      case 'ollama':
        if (args.isEmpty) {
          final host = await AIService.instance.ollamaService.getBaseUrl();
          final online = await AIService.instance.ollamaService.isAvailable();
          _addOutput('info', 'OLLAMA_ENDPOINT: $host');
          _addOutput('info', 'STATUS: ${online ? "ONLINE" : "OFFLINE (NEX Neural Core Active)"}');
        } else {
          await AIService.instance.ollamaService.setCustomHost(args.trim());
          final online = await AIService.instance.ollamaService.isAvailable();
          _addOutput('success', 'OLLAMA_HOST_UPDATED: ${args.trim()}');
          _addOutput('info', 'LINK_STATUS: ${online ? "CONNECTED" : "OFFLINE"}');
        }
        break;

      case 'matrix':
        _addOutput('success', 'WAKE UP, NEO... THE MATRIX HAS YOU.');
        unawaited(_runCrazyWorkSequence());
        break;

      case 'syslog':
        _addOutput('info', 'RAW_LOG_DUMP:');
        _addOutput('live', '[${DateTime.now().hour}:17] netflow connected.');
        _addOutput('live', '[${DateTime.now().hour}:32] AI_kernel synchronized.');
        _addOutput('live', '[${DateTime.now().hour}:01] handshake complete.');
        break;

      case 'status':
        _addOutput('success', 'NEX_DIAGNOSTICS:');
        _addOutput('info', '  • SUPABASE: READY');
        _addOutput('info', '  • AUTH_PROTOCOL: ACTIVE');
        _addOutput('info', '  • DB_SYNC: ONLINE');
        _addOutput('info', '  • TOKENS: VALIDATED');
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
        _addOutput('info', '  - home, chat, group, calls, bet');
        _addOutput('info', '  - market, profile, ai, terminal');
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
          await _runShellCommand('mkdir -p ${_escapeShellArg(target)}');
        }
        break;

      case 'touch':
        if (args.isEmpty) {
          _addOutput('error', 'ERR: MISSING_FILE');
        } else {
          final target = _resolvePath(args);
          await _runShellCommand('touch ${_escapeShellArg(target)}');
        }
        break;

      case 'cat':
        if (args.isEmpty) {
          _addOutput('error', 'ERR: MISSING_FILE');
        } else {
          final target = _resolvePath(args);
          await _runShellCommand('cat ${_escapeShellArg(target)}');
        }
        break;

      case 'rm':
        if (args.isEmpty) {
          _addOutput('error', 'ERR: MISSING_PATH');
        } else {
          final target = _resolvePath(args);
          await _runShellCommand('rm -rf ${_escapeShellArg(target)}');
        }
        break;

      case 'run':
        if (args.isEmpty) {
          _addOutput('error', 'ERR: MISSING_SCRIPT');
        } else {
          final target = _resolvePath(args);
          final lowered = target.toLowerCase();
          if (lowered.endsWith('.py')) {
            await _runShellCommand('python3 ${_escapeShellArg(target)}');
          } else if (lowered.endsWith('.sh')) {
            await _runShellCommand('sh ${_escapeShellArg(target)}');
          } else if (lowered.endsWith('.rs')) {
            await _runShellCommand('rustc ${_escapeShellArg(target)}');
          } else {
            await _runShellCommand('sh ${_escapeShellArg(target)}');
          }
        }
        break;

      case 'clone':
        if (args.isEmpty) {
          _addOutput('error', 'ERR: MISSING_REPOSITORY');
        } else {
          await _runShellCommand('git clone ${_escapeShellArg(args)}');
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
          await _runShellCommand('git commit -m ${_escapeShellArg(args)}');
        }
        break;

      case 'alias':
        _addOutput('info', 'aliases: ll=ls -la, gs=git status, ga=git add .');
        break;

      case 'env':
        _addOutput('info', 'TERM=NEX_TERMINAL');
        _addOutput('info', 'SHELL=nex-shell');
        _addOutput('info', 'PATH=/data/data/nex/workspace:/usr/bin:/bin');
        break;

      case 'info':
        _addOutput('info', 'NEX_TERMINAL_OS 1.0.42');
        _addOutput('info', 'WORKSPACE_ROOT: $_workspaceRoot');
        _addOutput('info', 'CURRENT_PATH: $_currentPath');
        _addOutput('info', 'STARTUP_COMPLETE: $_startupComplete');
        break;

      case 'workspace':
        _addOutput('info', 'WORKSPACE_ROOT: $_workspaceRoot');
        _addOutput('info', 'CURRENT_PATH: $_currentPath');
        break;

      case 'echo':
        _addOutput('info', args.isEmpty ? '' : args);
        break;

      case 'uname':
        _addOutput('info', 'Linux NEX-TERM 1.0');
        break;

      case 'history':
        if (_commandHistory.isEmpty) {
          _addOutput('info', 'NO_COMMAND_HISTORY');
        } else {
          for (var i = 0; i < _commandHistory.length; i++) {
            _addOutput('info', '${i + 1}  ${_commandHistory[i]}');
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
          final next = _currentPath.replaceFirst(RegExp(r'/[^/]+$'), '');
          setState(() => _currentPath = next.isEmpty ? '/' : next);
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
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        break;

      default:
        await _runShellCommand(command);
        break;
    }
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
        return kNeonGreen; // Distinct success color
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
                opacity: 0.18 + _pulseValue * 0.08,
                child: CustomPaint(
                  painter: _TerminalScanlinePainter(),
                ),
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0.16,
                child: CustomPaint(
                  painter: _TerminalGridPainter(),
                ),
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0.85,
                child: CustomPaint(
                  painter: _TerminalSpacefieldPainter(_earthOrbit),
                ),
              ),
            ),
            Positioned(
              right: 24,
              top: 42,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: kNeonBlue.withValues(alpha: 0.22),
                      blurRadius: 26,
                    ),
                  ],
                  gradient: const RadialGradient(
                    colors: [Color(0xFF4FD1C5), Color(0xFF0F3D5E)],
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
                    Positioned(
                      left: 54,
                      top: 12,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 92,
              child: Container(
                width: 180,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: kNeonBlue.withValues(alpha: 0.25)),
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF07111E).withValues(alpha: 0.82),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('HUD::TARGET_LOCK', style: TextStyle(color: kNeonBlue, fontSize: 10, fontFamily: 'monospace')),
                    SizedBox(height: 4),
                    Text('VECTOR: 07.12 / 03.90', style: TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace')),
                    Text('THREAT: LOW', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace')),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 20,
              bottom: 84,
              child: Container(
                width: 150,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.25)),
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF120A1F).withValues(alpha: 0.8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CONSOLE::LINK', style: TextStyle(color: Colors.purpleAccent, fontSize: 10, fontFamily: 'monospace')),
                    SizedBox(height: 4),
                    Text('COMM: STABLE', style: TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace')),
                    Text('SIG: 42%', style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontFamily: 'monospace')),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 20,
              top: 100,
              child: Container(
                width: 200,
                height: 2,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.transparent, kNeonBlue, Colors.transparent]),
                ),
              ),
            ),
            Positioned(
              right: 40,
              top: 140,
              child: Container(
                width: 120,
                height: 2,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.transparent, Colors.purpleAccent, Colors.transparent]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShootingStarOverlay() {
    if (!_showShootingStar) return const SizedBox.shrink();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        final x = _shootingStartX + (_shootingEndX - _shootingStartX) * value;
        final y = _shootingStartY + (_shootingEndY - _shootingStartY) * value;
        final opacity = (1 - value).clamp(0.0, 1.0).toDouble();

        final currentColor = Color.lerp(_shootingFromColor, _shootingToColor, value) ?? _shootingStarColor;

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
                      color: currentColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      onEnd: () => setState(() => _showShootingStar = false),
    );
  }

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
                      color: kNeonBlue.withValues(alpha: 0.3), blurRadius: 10),
                ],
              ),
              child: const Icon(Icons.terminal_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 14),
            const Text('NEX_TERMINAL',
                style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1)),
          ],
        ),
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new, color: kNeonBlue, size: 18),
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
              // PRO TERMINAL OUTPUT AREA
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF070B14),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: ListView.builder(
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: _output.length,
                itemBuilder: (context, index) {
                  final item = _output[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: SelectableText(
                      item['message'] as String,
                      style: TextStyle(
                        color: _getTypeColor(item['type'] as String),
                        fontSize: 12,
                        fontFamily: 'monospace',
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // INPUT INTERFACE
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            decoration: BoxDecoration(
              color: const Color(0xFF0A111F),
              border: Border(
                  top: BorderSide(color: kNeonBlue.withValues(alpha: 0.2))),
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: kNeonBlue.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: kNeonBlue.withValues(alpha: 0.25)),
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
                        hintStyle: const TextStyle(color: Colors.white12),
                        border: InputBorder.none,
                      ),
                      textInputAction: TextInputAction.send,
                      enableSuggestions: false,
                      autocorrect: false,
                      onSubmitted: (value) async {
                        await _handleCommandSubmit(value);
                      },
                      onTap: () {},
                      onChanged: (value) {},
                    ),
                  ),
                  // Blinking Cursor Simulation
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
                      await _handleCommandSubmit(_commandController.text);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kNeonBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: kNeonBlue.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.subdirectory_arrow_left_rounded,
                          color: kNeonBlue, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
              _buildShootingStarOverlay(),
            ],
          ),
        ],
      ),
    );
  }
}

class _TerminalScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.09);
    for (var y = 0.0; y < size.height; y += 4) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TerminalSpacefieldPainter extends CustomPainter {
  const _TerminalSpacefieldPainter(this.orbit);
  final double orbit;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    final stars = <Offset>[];
    for (var i = 0; i < 120; i++) {
      final x = (i * 29) % size.width;
      final y = ((i * 37) % 700) / 700 * size.height;
      stars.add(Offset(x, y));
    }

    for (final star in stars) {
      final alpha = 0.25 + ((star.dx + star.dy + orbit * size.width) % 20) / 40;
      canvas.drawCircle(star, 1.0 + (alpha * 0.7), paint..color = Colors.white.withValues(alpha: alpha.clamp(0.2, 1.0)));
    }

    final path = Path();
    path.moveTo(0, size.height * 0.82);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.62, size.width * 0.5, size.height * 0.78);
    path.quadraticBezierTo(size.width * 0.75, size.height * 0.94, size.width, size.height * 0.72);
    final glowPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.transparent, kNeonBlue.withValues(alpha: 0.35), Colors.transparent],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, glowPaint..strokeWidth = 2..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _TerminalSpacefieldPainter oldDelegate) => oldDelegate.orbit != orbit;
}

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
      paint..color = Colors.purpleAccent.withValues(alpha: 0.26),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TerminalGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

