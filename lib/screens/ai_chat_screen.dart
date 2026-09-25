import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ai_service.dart';
import '../services/game_sound_service.dart';
import '../utils/constants.dart';
import '../widgets/cyber_background.dart';

class AIChatScreen extends StatefulWidget {
  static const routeName = '/ai-chat';
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _pulseController;
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  String _serviceStatus = 'NEX CHRONEX CLOUD (ACTIVE)';
  bool _isOllamaOnline = false;
  String _currentHost = 'http://10.0.2.2:11434';

  final List<Map<String, String>> _modelOptions = const [
    {'key': 'gemini-flash-lite', 'label': 'ChronEX Gemini Flash Lite (NEXCHAT Multi-Key Cloud)', 'model': 'gemini-flash-lite-latest'},
    {'key': 'gemini-flash', 'label': 'ChronEX Gemini Flash (High Performance Cloud)', 'model': 'gemini-flash-latest'},
    {'key': 'gemini-pro', 'label': 'ChronEX Gemini Pro (Deep Logic & Code Cloud)', 'model': 'gemini-pro-latest'},
    {'key': 'qwen3.8', 'label': 'Qwen 3.8 (Quantum Velocity)', 'model': 'qwen3.8'},
    {'key': 'deepseek-v4', 'label': 'DeepSeek V4 Flash Cloud (Ultra Reasoning)', 'model': 'deepseek-v4-flash:cloud'},
    {'key': 'kimi-k3', 'label': 'Kimi K3 Cloud (Long-Context Engine)', 'model': 'kimi-k3:cloud'},
    {'key': 'ornith', 'label': 'Ornith 1.5 9B (Autonomous Agent)', 'model': 'ornith-1.5:9b'},
    {'key': 'laguna', 'label': 'Laguna XS 2.1 (Low-Latency Neural)', 'model': 'laguna-xs-2.1'},
    {'key': 'dolphin3', 'label': 'Dolphin 3 (Cyber Hacker)', 'model': 'dolphin3'},
    {'key': 'deepcoder', 'label': 'DeepCoder (Code Master)', 'model': 'deepcoder'},
    {'key': 'llama3', 'label': 'Llama 3.2 (Meta Neural)', 'model': 'llama3.2'},
    {'key': 'mistral', 'label': 'Mistral 7B (Logic Core)', 'model': 'mistral'},
    {'key': 'phi', 'label': 'Dolphin φ (Compact Core)', 'model': 'dolphin-phi'},
  ];

  final List<String> _suggestedPrompts = const [
    'Write a high-performance Flutter state controller',
    'Give me Cyber Racer 2099 high score secrets',
    'Run a network cyber defense diagnostic',
    'How do I purchase NEX VIP Tokens via Telegram?',
    'Explain NEX dual-sync database architecture',
  ];

  String _selectedModelKey = 'gemini-flash-lite';

  String get _selectedModel {
    return _modelOptions
        .firstWhere((option) => option['key'] == _selectedModelKey,
            orElse: () => _modelOptions.first)['model']!;
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _messages.add({
      'role': 'assistant',
      'content':
          '**NEX CHRONEX INTELLIGENCE HUB ONLINE**\n\nI am **NEX AI (ChronEX Core)**, powered directly by **NEXCHAT Google Gemini API Cloud Pool (Multi-Key Rotation & Auto-Failover)** and local neural backups. I provide high-velocity code generation, cyber diagnostics, and system architecture.\n\n*Tap the configuration icon to select models, test keys, or link a local server!*',
      'time': DateTime.now().toIso8601String(),
    });
    _refreshServiceStatus();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _submitPrompt(String prompt) async {
    _messageController.text = prompt;
    await _sendMessage();
  }

  Future<void> _refreshServiceStatus() async {
    final status = await AIService.instance.getIntegrationStatus();
    final isOnline = await AIService.instance.ollamaService.isAvailable();
    final host = await AIService.instance.ollamaService.getBaseUrl();
    if (!mounted) return;
    setState(() {
      _serviceStatus = status;
      _isOllamaOnline = isOnline;
      _currentHost = host;
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    HapticFeedback.selectionClick();
    GameSoundService().playLaser();

    setState(() {
      _messages.add({
        'role': 'user',
        'content': message,
        'time': DateTime.now().toIso8601String(),
      });
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    String aiResponse;

    try {
      aiResponse = await AIService.instance.chat(
        message,
        model: _selectedModel,
        conversationHistory: _messages,
      );
    } catch (e) {
      aiResponse = '[NEURAL FALLBACK] Processed query: $message\n\nNEX AI is running directly on local neural matrix. Error connecting to external host: $e';
    }

    await _refreshServiceStatus();

    if (!mounted) return;

    setState(() {
      _messages.add({
        'role': 'assistant',
        'content': aiResponse,
        'time': DateTime.now().toIso8601String(),
      });
      _isLoading = false;
    });

    GameSoundService().playCoin();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSettingsSheet() {
    final hostCtrl = TextEditingController(text: _currentHost);
    bool testing = false;
    String? testResult;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0C1122),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'AI CORE CONFIGURATION',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isOllamaOnline
                                ? kNeonGreen.withValues(alpha: 0.15)
                                : Colors.cyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isOllamaOnline ? kNeonGreen : Colors.cyan,
                            ),
                          ),
                          child: Text(
                            _isOllamaOnline ? 'OLLAMA CONNECTED' : 'CHRONEX CLOUD READY',
                            style: TextStyle(
                              color: _isOllamaOnline ? kNeonGreen : Colors.cyan,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'OLLAMA SERVER HOST / URL',
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: hostCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'http://192.168.1.X:11434',
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: const Color(0xFF141C33),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            testing ? Icons.hourglass_top_rounded : Icons.sensors_rounded,
                            color: kNeonBlue,
                          ),
                          onPressed: () async {
                            setModalState(() {
                              testing = true;
                              testResult = null;
                            });
                            await AIService.instance.ollamaService.setCustomHost(hostCtrl.text);
                            final ok = await AIService.instance.ollamaService.isAvailable();
                            await _refreshServiceStatus();
                            setModalState(() {
                              testing = false;
                              testResult = ok
                                  ? '[CONNECTED] Successfully connected to Ollama!'
                                  : '[OFFLINE] Server unreachable. ChronEX Gemini Cloud will handle queries automatically.';
                            });
                          },
                        ),
                      ),
                    ),
                    if (testResult != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        testResult!,
                        style: TextStyle(
                          color: testResult!.startsWith('[CONNECTED]') ? kNeonGreen : Colors.orangeAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('Emulator (10.0.2.2)', style: TextStyle(fontSize: 10, color: Colors.white70)),
                          backgroundColor: const Color(0xFF19223D),
                          onPressed: () {
                            hostCtrl.text = 'http://10.0.2.2:11434';
                          },
                        ),
                        ActionChip(
                          label: const Text('Localhost (127.0.0.1)', style: TextStyle(fontSize: 10, color: Colors.white70)),
                          backgroundColor: const Color(0xFF19223D),
                          onPressed: () {
                            hostCtrl.text = 'http://127.0.0.1:11434';
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'SELECT AI NEURAL MODEL',
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ..._modelOptions.map((option) {
                      final isSelected = _selectedModelKey == option['key'];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? kNeonBlue.withValues(alpha: 0.12) : const Color(0xFF13192E),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? kNeonBlue : Colors.white10,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: ListTile(
                          title: Text(
                            option['label']!,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            'Model Tag: ${option['model']}',
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded, color: kNeonBlue)
                              : null,
                          onTap: () async {
                            setState(() => _selectedModelKey = option['key']!);
                            await AIService.instance.ollamaService.setSelectedModel(option['model']!);
                            if (ctx.mounted) Navigator.pop(ctx);
                            _refreshServiceStatus();
                          },
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kNeonBlue,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          await AIService.instance.ollamaService.setCustomHost(hostCtrl.text);
                          await _refreshServiceStatus();
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('SAVE & RECONNECT', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leadingWidth: 46,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: kNeonBlue, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Row(
          children: [
            const Text(
              'NEX INTELLIGENCE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) {
                return Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isOllamaOnline ? kNeonGreen : Colors.cyanAccent,
                    boxShadow: [
                      BoxShadow(
                        color: (_isOllamaOnline ? kNeonGreen : Colors.cyanAccent)
                            .withValues(alpha: 0.4 + 0.4 * _pulseController.value),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: kNeonBlue),
            onPressed: _showSettingsSheet,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white54),
            onPressed: () {
              setState(() {
                _messages.clear();
                _messages.add({
                  'role': 'assistant',
                  'content': 'Neural session reset. ChronEX AI is ready for new operations.',
                  'time': DateTime.now().toIso8601String(),
                });
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: CyberBackground(
              starCount: 140,
              particleCount: 48,
              leftAuroraColors: [
                Color(0xFF0B91FF),
                Color(0xFF3BA5FF),
                Color(0x00000000),
              ],
              rightAuroraColors: [
                Color(0xFFBA52FF),
                Color(0xFFFF5ACD),
                Color(0x00000000),
              ],
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Status Strip
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Tooltip(
                        message: _serviceStatus,
                        child: _buildStatusChip(
                          _selectedModelKey.startsWith('gemini')
                              ? 'CHRONEX GEMINI LIVE'
                              : (_isOllamaOnline ? 'OLLAMA LIVE' : 'NEURAL CORE 3.0'),
                          _selectedModelKey.startsWith('gemini')
                              ? Colors.cyanAccent
                              : (_isOllamaOnline ? kNeonGreen : Colors.cyanAccent),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusChip(
                        _selectedModel.toUpperCase(),
                        kNeonPurple,
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _showSettingsSheet,
                        child: _buildStatusChip(
                          'CONFIG',
                          Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),

                // Quick Prompt Pills
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _suggestedPrompts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final p = _suggestedPrompts[i];
                      return ActionChip(
                        label: Text(
                          p,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        backgroundColor: const Color(0xFF121A30).withValues(alpha: 0.8),
                        side: BorderSide(color: Colors.cyanAccent.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        onPressed: () => _submitPrompt(p),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 8),

                // Messages Container
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF080D1C).withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isUser = message['role'] == 'user';
                        final content = message['content'] as String;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.82,
                              ),
                              decoration: BoxDecoration(
                                color: isUser ? const Color(0xFF162445) : const Color(0xFF0F182E),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(20),
                                  topRight: const Radius.circular(20),
                                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                                  bottomRight: Radius.circular(isUser ? 4 : 20),
                                ),
                                border: Border.all(
                                  color: isUser
                                      ? Colors.cyanAccent.withValues(alpha: 0.4)
                                      : kNeonBlue.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isUser ? Colors.cyan : kNeonBlue).withValues(alpha: 0.08),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isUser ? Icons.person_rounded : Icons.smart_toy_rounded,
                                        size: 14,
                                        color: isUser ? Colors.cyanAccent : kNeonBlue,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isUser ? 'OPERATOR' : 'NEX NEURAL CORE',
                                        style: TextStyle(
                                          color: isUser ? Colors.cyanAccent : kNeonBlue,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (!isUser)
                                        IconButton(
                                          icon: const Icon(Icons.copy_rounded, color: Colors.white38, size: 14),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: content));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Response copied to clipboard'),
                                                duration: Duration(seconds: 1),
                                              ),
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    content,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.95),
                                      fontSize: 14,
                                      height: 1.45,
                                      fontFamily: content.contains('```') ? 'monospace' : null,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                if (_isLoading) _buildAILoadingIndicator(),

                // Message Input Composer
                _buildMessageComposer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildAILoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0D162B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent),
              ),
              SizedBox(width: 10),
              Text(
                'NEURAL SYNTHESIS IN PROGRESS...',
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      decoration: const BoxDecoration(
        color: Color(0xFF080D1C),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF11182E),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.25)),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Ask anything, write code, run diagnostics...',
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.cyanAccent, kNeonBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withValues(alpha: 0.35),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
