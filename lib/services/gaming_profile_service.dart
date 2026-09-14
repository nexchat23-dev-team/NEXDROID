import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GamingProfileService {
  GamingProfileService._privateConstructor();
  static final GamingProfileService instance = GamingProfileService._privateConstructor();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<Map<String, dynamic>?> getProfile(String userId) {
    return _db.collection('gaming_profiles').doc(userId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return snapshot.data();
      }
      return null;
    });
  }

  Future<void> updateXP(String userId, int xpGained) async {
    final docRef = _db.collection('gaming_profiles').doc(userId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (snapshot.exists) {
        int currentXP = snapshot.data()?['totalXP'] ?? 0;
        int newXP = currentXP + xpGained;
        String newRank = getRankFromXP(newXP);
        transaction.update(docRef, {
          'totalXP': newXP,
          'rank': newRank,
        });
      }
    });
  }

  Future<void> recordGameResult({
    required String userId,
    required int kills,
    required int deaths,
    required bool won,
    required String gameType,
  }) async {
    final docRef = _db.collection('gaming_profiles').doc(userId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (snapshot.exists) {
        final data = snapshot.data()!;
        int tKills = (data['totalKills'] ?? 0) + kills;
        int tDeaths = (data['totalDeaths'] ?? 0) + deaths;
        int tWins = (data['totalWins'] ?? 0) + (won ? 1 : 0);
        int tGames = (data['totalGamesPlayed'] ?? 0) + 1;
        
        double kdRatio = tDeaths == 0 ? tKills.toDouble() : tKills / tDeaths;
        double winRate = tGames == 0 ? 0.0 : tWins / tGames;
        
        transaction.update(docRef, {
          'totalKills': tKills,
          'totalDeaths': tDeaths,
          'totalWins': tWins,
          'totalGamesPlayed': tGames,
          'kdRatio': kdRatio,
          'winRate': winRate,
        });
      }
    });
  }

  Future<void> unlockAchievement(String userId, String achievementId) async {
    final docRef = _db.collection('gaming_profiles').doc(userId);
    await docRef.update({
      'achievements': FieldValue.arrayUnion([achievementId])
    });
  }

  Stream<List<Map<String, dynamic>>> getLeaderboard() {
    return _db
        .collection('gaming_profiles')
        .orderBy('totalXP', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['userId'] = doc.id;
              return data;
            }).toList());
  }

  Stream<List<Map<String, dynamic>>> getClanLeaderboard() {
    return _db
        .collection('clans')
        .orderBy('totalClanXP', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['clanId'] = doc.id;
              return data;
            }).toList());
  }

  static String getRankFromXP(int xp) {
    if (xp >= 50000) return 'NexdroidLegend';
    if (xp >= 30000) return 'Immortal';
    if (xp >= 22000) return 'Legend';
    if (xp >= 15000) return 'GrandMaster';
    if (xp >= 10000) return 'Master';
    if (xp >= 6000) return 'Veteran';
    if (xp >= 3000) return 'Elite';
    if (xp >= 1500) return 'Soldier';
    if (xp >= 500) return 'Cadet';
    return 'Rookie';
  }

  static Color getRankColor(String rank) {
    switch (rank) {
      case 'NexdroidLegend': return const Color(0xFF00FF88);
      case 'Immortal': return const Color(0xFF00D4FF);
      case 'Legend': return const Color(0xFFB44FFF);
      case 'GrandMaster': return Colors.redAccent;
      case 'Master': return Colors.orangeAccent;
      case 'Veteran': return Colors.purpleAccent;
      case 'Elite': return Colors.blueAccent;
      case 'Soldier': return Colors.greenAccent;
      case 'Cadet': return Colors.tealAccent;
      case 'Rookie': default: return Colors.grey;
    }
  }

  static int getXPForNextRank(int currentXP) {
    if (currentXP < 500) return 500;
    if (currentXP < 1500) return 1500;
    if (currentXP < 3000) return 3000;
    if (currentXP < 6000) return 6000;
    if (currentXP < 10000) return 10000;
    if (currentXP < 15000) return 15000;
    if (currentXP < 22000) return 22000;
    if (currentXP < 30000) return 30000;
    if (currentXP < 50000) return 50000;
    return 50000; // maxed
  }
}
