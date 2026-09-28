import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DurationPlan {
  final int hours;
  final int tokens;
  final String label;
  final String badge;

  const DurationPlan({
    required this.hours,
    required this.tokens,
    required this.label,
    required this.badge,
  });
}

class MarketplaceService {
  static final MarketplaceService _instance = MarketplaceService._internal();
  factory MarketplaceService() => _instance;
  MarketplaceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? get currentUserId => _auth.currentUser?.uid;
  User? get currentUser => _auth.currentUser;

  // Exact Duration Plans from NEXCHAT
  static const Map<String, DurationPlan> durationPlans = {
    '48': DurationPlan(hours: 48, tokens: 100, label: '48 Hours', badge: 'Standard'),
    '72': DurationPlan(hours: 72, tokens: 150, label: '72 Hours (3 Days)', badge: 'Popular'),
    '144': DurationPlan(hours: 144, tokens: 300, label: '144 Hours (6 Days)', badge: 'Extended'),
    '168': DurationPlan(hours: 168, tokens: 350, label: '168 Hours (7 Days)', badge: 'Best Value'),
  };

  // Exact Categories from NEXCHAT
  static const List<Map<String, dynamic>> categories = [
    {'id': '', 'label': 'All', 'icon': Icons.storefront_rounded},
    {'id': 'electronics', 'label': 'Electronics', 'icon': Icons.devices_rounded},
    {'id': 'clothing', 'label': 'Fashion', 'icon': Icons.checkroom_rounded},
    {'id': 'gaming', 'label': 'Gaming', 'icon': Icons.sports_esports_rounded},
    {'id': 'services', 'label': 'Services', 'icon': Icons.handyman_rounded},
    {'id': 'books', 'label': 'Books', 'icon': Icons.menu_book_rounded},
    {'id': 'food', 'label': 'Food', 'icon': Icons.restaurant_rounded},
    {'id': 'furniture', 'label': 'Home', 'icon': Icons.chair_rounded},
    {'id': 'other', 'label': 'Other', 'icon': Icons.inventory_2_rounded},
  ];

  /// Upload media to Firebase Storage under advertisements/{uid}/
  Future<String> uploadMedia(File file, {required String uid, bool isVideo = false}) async {
    try {
      final ext = isVideo ? '.mp4' : '.jpg';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${pathClean(file.path)}$ext';
      final ref = _storage.ref().child('advertisements').child(uid).child(fileName);
      final metadata = SettableMetadata(
        contentType: isVideo ? 'video/mp4' : 'image/jpeg',
      );
      final uploadTask = await ref.putFile(file, metadata);
      final url = await uploadTask.ref.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint('[MarketplaceService] Media upload error: $e');
      rethrow;
    }
  }

  static String pathClean(String p) {
    return p.split(RegExp(r'[\\/]')).last.replaceAll(RegExp(r'[^a-zA-Z0-9.-]'), '_');
  }

  /// Publish new Advertisement matching NEXCHAT Firestore schema
  Future<String> publishAdvertisement({
    required String productName,
    required String productDescription,
    required double productPrice,
    required String productCategory,
    required String imageURL,
    required String mediaType, // 'image' or 'video'
    required int durationHours,
    required int durationTokens,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Authentication required');

    final userRef = _firestore.collection('users').doc(user.uid);
    final userSnap = await userRef.get();
    final currentTokens = (userSnap.data()?['tokens'] as num?)?.toInt() ?? 0;

    if (currentTokens < durationTokens) {
      throw Exception('Insufficient tokens. Required: $durationTokens, Available: $currentTokens');
    }

    final expiresAt = DateTime.now().add(Duration(hours: durationHours));
    final username = userSnap.data()?['username'] ?? userSnap.data()?['name'] ?? user.displayName ?? 'NEX User';
    final email = user.email ?? 'No email';

    final adData = {
      'productName': productName,
      'productDescription': productDescription,
      'productPrice': productPrice,
      'productCategory': productCategory,
      'imageURL': imageURL,
      'mediaType': mediaType,
      'sellerUID': user.uid,
      'sellerUsername': username,
      'sellerEmail': email,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'durationHours': durationHours,
      'durationTokens': durationTokens,
      'status': 'active',
      'views': 0,
    };

    // Add Advertisement to Firestore
    final docRef = await _firestore.collection('advertisements').add(adData);

    // Deduct user tokens in Firestore
    await userRef.update({
      'tokens': FieldValue.increment(-durationTokens),
    });

    return docRef.id;
  }

  /// Stream of Active Advertisements from Firestore
  Stream<List<Map<String, dynamic>>> getActiveAdsStream({String? category, String? searchQuery}) {
    return _firestore
        .collection('advertisements')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
          final now = DateTime.now();
          final list = <Map<String, dynamic>>[];

          for (final doc in snap.docs) {
            final data = doc.data();
            data['id'] = doc.id;

            // Expiry check
            final exp = data['expiresAt'];
            DateTime? expiryDate;
            if (exp is Timestamp) {
              expiryDate = exp.toDate();
            } else if (exp is String) {
              expiryDate = DateTime.tryParse(exp);
            }

            if (expiryDate != null && expiryDate.isBefore(now)) {
              continue; // Skip expired
            }

            // Category filter
            if (category != null && category.isNotEmpty) {
              final cat = (data['productCategory'] ?? '').toString().toLowerCase();
              if (cat != category.toLowerCase()) continue;
            }

            // Search filter
            if (searchQuery != null && searchQuery.isNotEmpty) {
              final q = searchQuery.toLowerCase();
              final name = (data['productName'] ?? '').toString().toLowerCase();
              final desc = (data['productDescription'] ?? '').toString().toLowerCase();
              final seller = (data['sellerUsername'] ?? '').toString().toLowerCase();
              if (!name.contains(q) && !desc.contains(q) && !seller.contains(q)) {
                continue;
              }
            }

            list.add(data);
          }
          return list;
        });
  }

  /// Stream of User's listings
  Stream<List<Map<String, dynamic>>> getMyAdsStream(String uid) {
    return _firestore
        .collection('advertisements')
        .where('sellerUID', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
          list.sort((a, b) {
            final tA = a['createdAt'] as Timestamp?;
            final tB = b['createdAt'] as Timestamp?;
            return (tB?.seconds ?? 0).compareTo(tA?.seconds ?? 0);
          });
          return list;
        });
  }

  /// Increment views on an ad
  Future<void> incrementView(String adId) async {
    try {
      await _firestore.collection('advertisements').doc(adId).update({
        'views': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  /// Delete an ad
  Future<void> deleteAd(String adId) async {
    await _firestore.collection('advertisements').doc(adId).delete();
  }

  // ── CART PERSISTENCE (LocalStorage / SharedPreferences) ─────────────────────
  static const String _cartKey = 'nexchat_market_cart_items';

  Future<List<Map<String, dynamic>>> getCartItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cartKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addToCart(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getCartItems();
    final exists = items.any((i) => i['id'] == item['id']);
    if (!exists) {
      items.add(item);
      await prefs.setString(_cartKey, jsonEncode(items));
    }
  }

  Future<void> removeFromCart(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getCartItems();
    items.removeWhere((i) => i['id'] == id);
    await prefs.setString(_cartKey, jsonEncode(items));
  }

  Future<void> clearCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cartKey);
  }
}
