import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class MarketplaceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final MarketplaceService _instance = MarketplaceService._internal();

  factory MarketplaceService() {
    return _instance;
  }

  MarketplaceService._internal();

  String? get currentUserId => _auth.currentUser?.uid;

  Map<String, dynamic> _addIdToData(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = Map<String, dynamic>.from(doc.data() ?? {});
    data['id'] = doc.id;
    return data;
  }

  Future<String> createListing({
    required String title,
    required String description,
    required double price,
    required String currency,
    required List<String> images,
    required String category,
  }) async {
    try {
      if (currentUserId == null) throw Exception('No current user');

      final ref = await _firestore.collection('marketplace').add({
        'sellerId': currentUserId,
        'title': title,
        'description': description,
        'price': price,
        'currency': currency,
        'images': images,
        'category': category,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'views': 0,
      });
      return ref.id;
    } catch (e) {
      debugPrint('Error creating listing: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getActiveListings() {
    return _firestore
        .collection('marketplace')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => _addIdToData(doc)).toList());
  }

  Future<void> makeOffer(String listingId, double offerAmount) async {
    try {
      if (currentUserId == null) throw Exception('No current user');
      
      final doc = await _firestore.collection('marketplace').doc(listingId).get();
      if (!doc.exists) throw Exception('Listing not found');
      
      final sellerId = doc['sellerId'];
      if (sellerId == currentUserId) throw Exception('Cannot make an offer on your own listing');

      await _firestore.collection('marketplaceOffers').add({
        'listingId': listingId,
        'buyerId': currentUserId,
        'sellerId': sellerId,
        'amount': offerAmount,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error making offer: $e');
      rethrow;
    }
  }

  Future<void> updateListingStatus(String listingId, String status) async {
    try {
      if (currentUserId == null) throw Exception('No current user');
      
      final doc = await _firestore.collection('marketplace').doc(listingId).get();
      if (doc['sellerId'] != currentUserId) throw Exception('Not authorized');

      await _firestore.collection('marketplace').doc(listingId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating listing: $e');
      rethrow;
    }
  }
}
