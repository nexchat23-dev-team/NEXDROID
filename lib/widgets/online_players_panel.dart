import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/backend_service.dart';

class OnlinePlayersPanel extends StatefulWidget {
  final String gameName;

  const OnlinePlayersPanel({Key? key, required this.gameName}) : super(key: key);

  @override
  _OnlinePlayersPanelState createState() => _OnlinePlayersPanelState();
}

class _OnlinePlayersPanelState extends State<OnlinePlayersPanel> {
  List<dynamic> _players = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchPlayers();
  }

  Future<void> _fetchPlayers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Execute the call using the format requested by user
      dynamic response;
      try {
        response = await SupabaseService.client.from('users').select().limit(20).execute();
      } catch (_) {
        // Fallback for newer supabase packages
        response = await SupabaseService.client.from('users').select().limit(20);
      }
      
      List<dynamic> data = [];
      if (response is List) {
        data = response;
      } else if (response != null && response.data != null) {
        data = response.data as List<dynamic>;
      } else {
        data = response as List<dynamic>;
      }

      setState(() {
        _players = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load players';
        _isLoading = false;
      });
    }
  }

  void _challengePlayer(String username) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Challenge sent to $username!'),
        backgroundColor: const Color(0xFFB23BFF), // Neon Purple
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00B8F4).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00B8F4).withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ONLINE NEXDROID GAMERS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        shadows: [
                          Shadow(
                            color: const Color(0xFF25D366).withOpacity(0.8),
                            blurRadius: 8,
                          )
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF25D366)),
                      ),
                      child: Text(
                        _isLoading ? '...' : '${_players.length}',
                        style: const TextStyle(
                          color: Color(0xFF25D366),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Playing: ${widget.gameName}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 16),
                
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B8F4)),
                      ),
                    ),
                  )
                else if (_errorMessage.isNotEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  )
                else if (_players.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                        'No players currently online.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _players.length,
                      itemBuilder: (context, index) {
                        final player = _players[index];
                        final username = player['username'] ?? 'Unknown';
                        final status = player['status'] ?? 'ONLINE';
                        
                        Color statusColor;
                        switch (status) {
                          case 'IN-GAME':
                            statusColor = const Color(0xFFB23BFF); // Purple
                            break;
                          case 'IDLE':
                            statusColor = Colors.orangeAccent;
                            break;
                          default:
                            statusColor = const Color(0xFF25D366); // Green
                        }
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFF00B8F4).withOpacity(0.2),
                                child: Text(
                                  username.toString().isNotEmpty ? username.toString()[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    color: Color(0xFF00B8F4),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      username,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: statusColor,
                                            boxShadow: [
                                              BoxShadow(
                                                color: statusColor.withOpacity(0.8),
                                                blurRadius: 4,
                                              )
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          status,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => _challengePlayer(username),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFB23BFF).withOpacity(0.2),
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Color(0xFFB23BFF)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                child: const Text(
                                  'CHALLENGE',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
