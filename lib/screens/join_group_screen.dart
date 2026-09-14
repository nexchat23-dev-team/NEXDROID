import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import 'group_chat_screen.dart';
import '../utils/constants.dart';

class JoinGroupScreen extends StatefulWidget {
  static const String routeName = '/join-group';

  const JoinGroupScreen({Key? key}) : super(key: key);

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen>
    with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final TextEditingController _inviteCodeController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  Map<String, dynamic>? _groupPreview;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _inviteCodeController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _searchGroup() async {
    final code = _inviteCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter an invite code';
        _groupPreview = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _groupPreview = null;
    });

    try {
      final groupData = await _chatService.findGroupByInviteCode(code);
      if (groupData != null) {
        setState(() {
          _groupPreview = groupData;
        });
        _animController.forward(from: 0);
      } else {
        setState(() {
          _errorMessage = 'Invalid invite code. Please check and try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _joinGroup() async {
    if (_groupPreview == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final code = _inviteCodeController.text.trim().toUpperCase();
      final result = await _chatService.joinGroupByInviteCode(code);

      if (mounted) {
        if (result != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Successfully joined group.'),
                backgroundColor: kNeonGreen),
          );

          Navigator.pushReplacementNamed(
            context,
            GroupChatScreen.routeName,
            arguments: result,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Join request sent. Waiting for admin approval.'),
              duration: Duration(seconds: 3),
              backgroundColor: kNeonBlue,
            ),
          );

          setState(() {
            _inviteCodeController.clear();
            _groupPreview = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBackground,
      appBar: AppBar(
        title: const Text('Join Group',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kPrimaryBlue,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kNeonPurple.withValues(alpha: 0.2),
                    kNeonBlue.withValues(alpha: 0.1)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: kNeonPurple.withValues(alpha: 0.3), width: 2),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.groups_2, color: kNeonGreen, size: 40),
                  SizedBox(height: 12),
                  Text(
                    'Find & Join Groups',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Enter a group invite code to find and join communities',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Invite Code Input
            const Text('Invite Code',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _inviteCodeController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'e.g., ABC123XYZ',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.vpn_key, color: kNeonBlue),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: kNeonBlue, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Search Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _searchGroup,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
              label: Text(_isLoading ? 'Searching...' : 'Search Group'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kNeonBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
            ),
            const SizedBox(height: 20),

            // Error Message
            if (_errorMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Text(_errorMessage,
                    style: const TextStyle(color: Colors.red, fontSize: 14)),
              ),

            // Group Preview
            if (_groupPreview != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      kNeonGreen.withValues(alpha: 0.15),
                      kNeonBlue.withValues(alpha: 0.1)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: kNeonGreen.withValues(alpha: 0.4), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Group Found',
                      style: TextStyle(
                          color: kNeonGreen,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                        'Group Name', _groupPreview?['name'] ?? 'Unknown'),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                        'Members', '${_groupPreview?['memberCount'] ?? 0}'),
                    const SizedBox(height: 12),
                    _buildInfoRow('Description',
                        _groupPreview?['description'] ?? 'No description'),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _joinGroup,
                      icon: const Icon(Icons.done_all),
                      label: Text(_isLoading ? 'Joining...' : 'Join Group'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kNeonGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
        Expanded(
          flex: 3,
          child: Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
