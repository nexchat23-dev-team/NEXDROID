import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';

class MatchmakingService {
  static final MatchmakingService instance = MatchmakingService._internal();
  MatchmakingService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final Uuid _uuid = const Uuid();

  /// Creates a new gaming lobby and returns the lobby ID
  Future<String> createLobby(String gameName, String hostName, int maxPlayers, {String? hostId}) async {
    final lobbyId = _uuid.v4();
    final realHostId = hostId ?? _uuid.v4();
    final ref = _db.ref('gaming_lobbies/$lobbyId');
    await ref.set({
      'id': lobbyId,
      'gameName': gameName,
      'hostId': realHostId,
      'hostName': hostName,
      'maxPlayers': maxPlayers,
      'status': 'WAITING',
      'createdAt': ServerValue.timestamp,
      'players': {
        realHostId: {
          'id': realHostId,
          'username': hostName,
          'joinedAt': ServerValue.timestamp,
        }
      }
    });
    return lobbyId;
  }

  /// Adds a player to a specific lobby
  Future<void> joinLobby(String lobbyId, String userId, String username) async {
    final ref = _db.ref('gaming_lobbies/$lobbyId/players/$userId');
    await ref.set({
      'id': userId,
      'username': username,
      'joinedAt': ServerValue.timestamp,
    });
  }

  /// Removes a player from a lobby
  Future<void> leaveLobby(String lobbyId, String userId) async {
    final ref = _db.ref('gaming_lobbies/$lobbyId/players/$userId');
    await ref.remove();
  }

  /// Stream of all active lobbies
  Stream<List<Map<String, dynamic>>> getLobbies() {
    return _db.ref('gaming_lobbies').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];
      
      final mapData = data as Map<dynamic, dynamic>;
      final List<Map<String, dynamic>> lobbies = [];
      
      mapData.forEach((key, value) {
        if (value is Map) {
          lobbies.add(Map<String, dynamic>.from(value));
        }
      });
      
      return lobbies..sort((a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0));
    });
  }

  /// Stream of a specific lobby by ID
  Stream<Map<String, dynamic>?> getLobby(String lobbyId) {
    return _db.ref('gaming_lobbies/$lobbyId').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return null;
      return Map<String, dynamic>.from(data as Map);
    });
  }

  /// Sets online presence for a user
  Future<void> setPresence(String userId, String username, String status, {String? game}) async {
    final ref = _db.ref('gaming_presence/$userId');
    await ref.set({
      'id': userId,
      'username': username,
      'status': status,
      'game': game ?? '',
      'timestamp': ServerValue.timestamp,
    });
    
    // Automatically remove presence on disconnect
    ref.onDisconnect().remove();
  }

  /// Clears presence for a user (e.g. on logout or dispose)
  Future<void> clearPresence(String userId) async {
    final ref = _db.ref('gaming_presence/$userId');
    await ref.remove();
  }

  /// Stream of all online players
  Stream<List<Map<String, dynamic>>> getOnlinePlayers() {
    return _db.ref('gaming_presence').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];
      
      final mapData = data as Map<dynamic, dynamic>;
      final List<Map<String, dynamic>> players = [];
      
      mapData.forEach((key, value) {
        if (value is Map) {
          players.add(Map<String, dynamic>.from(value));
        }
      });
      
      return players;
    });
  }

  /// Sends a direct challenge to a player
  Future<void> sendChallenge(String fromUserId, String fromUsername, String toUserId, String gameName) async {
    final challengeId = _uuid.v4();
    final ref = _db.ref('gaming_challenges/$toUserId/$challengeId');
    await ref.set({
      'id': challengeId,
      'fromUserId': fromUserId,
      'fromUsername': fromUsername,
      'toUserId': toUserId,
      'gameName': gameName,
      'status': 'PENDING',
      'createdAt': ServerValue.timestamp,
    });
  }

  /// Stream of incoming challenges for a specific user
  Stream<List<Map<String, dynamic>>> getIncomingChallenges(String userId) {
    return _db.ref('gaming_challenges/$userId').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];
      
      final mapData = data as Map<dynamic, dynamic>;
      final List<Map<String, dynamic>> challenges = [];
      
      mapData.forEach((key, value) {
        if (value is Map) {
          challenges.add(Map<String, dynamic>.from(value));
        }
      });
      
      return challenges..sort((a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0));
    });
  }

  /// Declines (deletes) a challenge
  Future<void> deleteChallenge(String userId, String challengeId) async {
    final ref = _db.ref('gaming_challenges/$userId/$challengeId');
    await ref.remove();
  }
}
