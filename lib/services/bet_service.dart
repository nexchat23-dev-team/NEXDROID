import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class BetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final BetService _instance = BetService._internal();

  factory BetService() {
    return _instance;
  }

  BetService._internal();

  String? get currentUserId => _auth.currentUser?.uid;

  Map<String, dynamic> _addIdToData(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = Map<String, dynamic>.from(doc.data() ?? {});
    data['id'] = doc.id;
    return data;
  }

  Stream<List<Map<String, dynamic>>> getActiveBets() {
    return _firestore
        .collection('bets')
        .where('status', isEqualTo: 'open')
        .orderBy('closingTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => _addIdToData(doc)).toList());
  }

  Future<void> placeBet(String betId, String option, double amount) async {
    try {
      if (currentUserId == null) throw Exception('No current user');

      final betDoc = await _firestore.collection('bets').doc(betId).get();
      if (!betDoc.exists) throw Exception('Bet not found');
      
      if (betDoc['status'] != 'open') throw Exception('Bet is no longer open');
      
      // We would also deduct balance here in a real transaction
      
      await _firestore.collection('betSlips').add({
        'betId': betId,
        'userId': currentUserId,
        'option': option,
        'amount': amount,
        'status': 'pending', // pending, won, lost
        'placedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error placing bet: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getUserBetSlips() {
    if (currentUserId == null) return const Stream.empty();
    
    return _firestore
        .collection('betSlips')
        .where('userId', isEqualTo: currentUserId)
        .orderBy('placedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => _addIdToData(doc)).toList());
  }
}
