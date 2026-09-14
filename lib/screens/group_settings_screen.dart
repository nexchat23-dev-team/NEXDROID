import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../utils/constants.dart';

class GroupSettingsScreen extends StatefulWidget {
  final String conversationId;
  final String groupName;

  const GroupSettingsScreen({
    super.key,
    required this.conversationId,
    required this.groupName,
  });

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final ChatService _chatService = ChatService();
  bool _autoJoinEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final autoJoin =
          await _chatService.getAutoJoinSetting(widget.conversationId);
      setState(() {
        _autoJoinEnabled = autoJoin;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    }
  }

  Future<void> _toggleAutoJoin(bool value) async {
    try {
      await _chatService.setAutoJoinSetting(widget.conversationId, value);
      if (mounted) {
        setState(() {
          _autoJoinEnabled = value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Auto-join enabled - users can join immediately'
                  : 'Auto-join disabled - users must request to join',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kDarkBackground,
        title: Text(
          '${widget.groupName} - Settings',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF0F0F1E),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: kNeonPurple),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Auto-Join Setting Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          kNeonPurple.withValues(alpha: 0.15),
                          kNeonDarkPurple.withValues(alpha: 0.15)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kNeonPurple.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: kNeonPurple.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.lock_open,
                                color: kNeonPurple,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Auto-Join Setting',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _autoJoinEnabled
                                        ? 'Users can join immediately with invite link'
                                        : 'Users must request to join (admin approval needed)',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _autoJoinEnabled,
                              onChanged: _toggleAutoJoin,
                              activeThumbColor: kNeonGreen,
                              inactiveThumbColor: Colors.white54,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Pending Requests Section
                  const Text(
                    'Pending Join Requests',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _chatService
                        .getPendingJoinRequests(widget.conversationId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: kNeonPurple),
                        );
                      }

                      if (snapshot.hasError) {
                        return const Center(
                          child: Text(
                            'Error loading requests',
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }

                      final requests = snapshot.data ?? [];

                      if (requests.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 48,
                                color: kNeonGreen.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No pending requests',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        children: List.generate(requests.length, (index) {
                          final requestData = requests[index];
                          final userId = requestData['user_id']?.toString() ??
                              requestData['userId']?.toString() ?? '';
                          final userEmail = requestData['user_email'] ??
                              requestData['userEmail'] ?? 'Unknown User';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF1A1A2E),
                                  Color(0xFF1E1E3A),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            kNeonPurple.withValues(alpha: 0.6),
                                            kNeonDarkPurple.withValues(alpha: 0.6),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          userEmail.isEmpty
                                              ? 'U'
                                              : userEmail[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            userEmail,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Requesting to join',
                                            style: TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            _rejectRequest(userId, userEmail),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                              color: Colors.red),
                                          foregroundColor: Colors.red,
                                        ),
                                        child: const Text('Reject'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () =>
                                            _approveRequest(userId, userEmail),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: kNeonGreen,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Approve'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _approveRequest(String userId, String userName) async {
    try {
      await _chatService.approveJoinRequest(widget.conversationId, userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$userName approved to join!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _rejectRequest(String userId, String userName) async {
    try {
      await _chatService.rejectJoinRequest(widget.conversationId, userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$userName request rejected')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
