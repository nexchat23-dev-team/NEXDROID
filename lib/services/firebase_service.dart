import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'cloudinary_storage_service.dart';
import 'storage_api_service.dart';
import 'vercel_blob_service.dart';

class FirebaseService {
  static FirebaseApp? _app;
  static FirebaseDatabase? _realtime;
  static bool _initializationFailed = false;
  static const String _databaseUrl = 'https://nexchat-47326-default-rtdb.firebaseio.com/';

  static const FirebaseOptions nexchatFirebaseOptions = FirebaseOptions(
    apiKey: 'AIzaSyAoE3QKqT_H9SJ_sYes0wfZdlKG82qRfIk',
    appId: '1:327330605104:android:ca35cc55624a0e651065f5',
    messagingSenderId: '327330605104',
    projectId: 'nexchat-47326',
    storageBucket: 'nexchat-47326.firebasestorage.app',
    databaseURL: 'https://nexchat-47326-default-rtdb.firebaseio.com',
  );

  static Future<void> initialize() async {
    if (_initializationFailed) return;
    try {
      if (Firebase.apps.isEmpty) {
        try {
          _app = await Firebase.initializeApp();
        } catch (e) {
          debugPrint('[FirebaseService] Default init error, using nexchatFirebaseOptions: $e');
          _app = await Firebase.initializeApp(options: nexchatFirebaseOptions);
        }
      } else {
        _app = Firebase.app();
      }
      try {
        _realtime ??= FirebaseDatabase.instanceFor(
          app: _app!,
          databaseURL: _databaseUrl,
        );
        try {
          FirebaseFirestore.instance.settings = const Settings(
            persistenceEnabled: true,
            cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
          );
        } catch (e) {
          debugPrint('[FirebaseService] Firestore settings note: $e');
        }
        if (auth.currentUser != null) {
          unawaited(_cleanupRealtimeUserEntrySafely(uid: auth.currentUser!.uid));
          unawaited(setUserPresence(uid: auth.currentUser!.uid, isOnline: true));
        }
      } catch (e) {
        debugPrint('[FirebaseService] RTDB bypass/notice: $e');
      }
    } catch (e) {
      if (shouldTreatInitializationErrorAsFatal(e)) {
        _initializationFailed = true;
      }
      debugPrint('Firebase initialization issue: $e');
    }
  }

  static bool shouldTreatInitializationErrorAsFatal(Object error) {
    if (error is FirebaseException) {
      final code = error.code.toLowerCase();
      return !code.contains('permission') && !code.contains('network') && !code.contains('unavailable');
    }
    return true;
  }

  static Future<void> _cleanupRealtimeUserEntrySafely({String? uid}) async {
    try {
      await cleanupNullRealtimeEntries(uid: uid);
    } catch (e) {
      debugPrint('Realtime cleanup skipped: $e');
    }
  }

  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  static FirebaseDatabase? get realtimeNullable {
    try {
      if (_realtime != null) return _realtime!;
      if (_app == null) return null;
      _realtime ??= FirebaseDatabase.instanceFor(
        app: _app!,
        databaseURL: _databaseUrl,
      );
      return _realtime;
    } catch (e) {
      debugPrint('[FirebaseService] RTDB unavailable: $e');
      return null;
    }
  }

  static FirebaseDatabase get realtime {
    return realtimeNullable ?? FirebaseDatabase.instance;
  }
  static FirebaseStorage get storage => FirebaseStorage.instance;

  static bool get isAvailable => _app != null && !_initializationFailed;

  static Map<String, dynamic> sanitizeRealtimeData(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};
    for (final entry in data.entries) {
      if (entry.value == null) continue;
      if (entry.value is Map) {
        final nested = sanitizeRealtimeData(
          Map<String, dynamic>.from(entry.value as Map),
        );
        if (nested.isNotEmpty) {
          sanitized[entry.key] = nested;
        }
      } else if (entry.value is List) {
        final list = <dynamic>[];
        for (final item in entry.value as List) {
          if (item == null) continue;
          if (item is Map) {
            final nestedItem = sanitizeRealtimeData(Map<String, dynamic>.from(item));
            if (nestedItem.isNotEmpty) {
              list.add(nestedItem);
            }
          } else {
            list.add(item);
          }
        }
        if (list.isNotEmpty || entry.value is! List) {
          sanitized[entry.key] = list;
        }
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return sanitized;
  }

  static Future<void> setUserPresence({required String uid, required bool isOnline}) async {
    if (!isAvailable || uid.isEmpty) return;

    final now = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'uid': uid,
      'isOnline': isOnline,
      'lastSeen': now,
    };

    try {
      final presenceRef = realtime.ref('presence/$uid');
      final loggedUsersRef = realtime.ref('logged_users/$uid');

      if (isOnline) {
        await presenceRef.set(payload).timeout(const Duration(seconds: 3));
        await loggedUsersRef.set(payload).timeout(const Duration(seconds: 3));
        presenceRef.onDisconnect().set({'uid': uid, 'isOnline': false, 'lastSeen': now}).catchError((_) {});
        loggedUsersRef.onDisconnect().remove().catchError((_) {});
      } else {
        await presenceRef.set({'uid': uid, 'isOnline': false, 'lastSeen': now}).timeout(const Duration(seconds: 3));
        await loggedUsersRef.remove().timeout(const Duration(seconds: 3));
      }
    } catch (e) {
      debugPrint('Presence update skipped/timed out: $e');
    }
  }

  static Future<void> signIn(String email, String password) async {
    await auth.signInWithEmailAndPassword(email: email, password: password).timeout(const Duration(seconds: 15));
  }

  static Future<void> cleanupNullRealtimeEntries({String? uid}) async {
    if (!isAvailable) return;
    final targetUid = uid ?? auth.currentUser?.uid;
    if (targetUid == null || targetUid.isEmpty) return;

    try {
      final userRef = realtime.ref('users/$targetUid');
      final snapshot = await userRef.get().timeout(const Duration(seconds: 3));
      if (!snapshot.exists || snapshot.value is! Map) return;

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final cleaned = sanitizeRealtimeData(data);

      if (cleaned.length != data.length) {
        await userRef.set(cleaned).timeout(const Duration(seconds: 3));
      }
    } catch (e) {
      debugPrint('Realtime cleanup skipped: $e');
    }
  }

  static Future<void> signUp(String email, String password) async {
    await auth.createUserWithEmailAndPassword(email: email, password: password).timeout(const Duration(seconds: 15));
  }

  static List<String> defaultGameGenres() => const [
        'Adventure',
        'Action',
        'Racing',
        'Horror',
        'Thriller',
        'Strategy',
        'Puzzle',
      ];

  static List<String> defaultGameBadges() => const [
        'Adventure Trailblazer',
        'Action Ace',
        'Racing Rampage',
        'Thriller Survivor',
        'Puzzle Master',
      ];

  static Map<String, dynamic> buildRealtimeUserProfilePayload({
    required String uid,
    required String email,
    required String username,
    String? displayName,
    String? photoUrl,
    int? tokenBalance,
    bool? dailyBonusClaimed,
    List<String>? gameGenres,
    List<String>? gameBadges,
    int? age,
    String? ipAddress,
    String? country,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'name': displayName ?? username,
      'online': false,
      'profilePic': photoUrl != null && photoUrl.isNotEmpty ? 'avatar' : '',
      'profilePicUrl': photoUrl ?? '',
      'registrationTimestamp': now,
      'tokens': tokenBalance ?? 2000,
      'photo_url': photoUrl ?? '',
      'token_balance': tokenBalance ?? 2000,
      'daily_bonus_claimed': dailyBonusClaimed ?? false,
      'allowIncomingMessages': true,
      'allowAnyUserMessage': true,
      'allowIncomingCalls': true,
      'streak_count': 0,
      'best_streak': 0,
      'last_check_in_date': null,
      'streak_milestones_reached': <String>[],
      'daily_challenges_completed': <String>[],
      'game_genres': gameGenres ?? defaultGameGenres(),
      'game_badges': gameBadges ?? defaultGameBadges(),
      'quick_notes': '',
      'age': age,
      'ip_address': ipAddress,
      'country': country,
      'created_at': now,
      'updated_at': now,
    };
  }

  static Future<void> saveUserProfile({
    required String uid,
    required String email,
    required String username,
    String? displayName,
    String? photoUrl,
    int? tokenBalance,
    bool? dailyBonusClaimed,
    List<String>? gameGenres,
    List<String>? gameBadges,
    int? age,
    String? ipAddress,
    String? country,
  }) async {
    if (_app == null) return;
    final firestoreData = <String, dynamic>{
      'id': uid,
      'uid': uid,
      'email': email,
      'username': username,
      'name': displayName ?? username,
      'photo_url': photoUrl ?? '',
      'token_balance': tokenBalance ?? 2000,
      'daily_bonus_claimed': dailyBonusClaimed ?? false,
      'streak_count': 0,
      'best_streak': 0,
      'streak_milestones_reached': <String>[],
      'daily_challenges_completed': <String>[],
      'game_genres': gameGenres ?? defaultGameGenres(),
      'game_badges': gameBadges ?? defaultGameBadges(),
      'quick_notes': '',
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };

    if (age != null) {
      firestoreData['age'] = age;
    }
    if (ipAddress != null && ipAddress.isNotEmpty) {
      firestoreData['ip_address'] = ipAddress;
    }
    if (country != null && country.isNotEmpty) {
      firestoreData['country'] = country;
    }

    // Only add optional fields when they are non-null and valid.
    if (displayName != null && displayName.isNotEmpty) {
      firestoreData['name'] = displayName;
    }

    try {
      await firestore
          .collection('users')
          .doc(uid)
          .set(firestoreData, SetOptions(merge: true))
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('[FirebaseService] Firestore saveUserProfile warning: $e');
    }

    final realtimeData = buildRealtimeUserProfilePayload(
      uid: uid,
      email: email,
      username: username,
      displayName: displayName,
      photoUrl: photoUrl,
      tokenBalance: tokenBalance,
      dailyBonusClaimed: dailyBonusClaimed,
      age: age,
      ipAddress: ipAddress,
      country: country,
    );
    unawaited(_saveUserProfileRealtimeSafely(uid: uid, data: realtimeData));
  }

  static Future<void> _saveUserProfileRealtimeSafely({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _saveUserProfileRealtime(uid: uid, data: data);
    } catch (e) {
      debugPrint('Realtime profile write failed: $e');
    }
  }

  static Future<void> _saveUserProfileRealtime({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final realtimeData = <String, dynamic>{
        ...data,
        'updated_at': now,
      };

      if (data['created_at'] is FieldValue) {
        realtimeData['created_at'] = now;
      } else if (data.containsKey('created_at') && data['created_at'] != null) {
        realtimeData['created_at'] = data['created_at'];
      }

      final sanitizedData = sanitizeRealtimeData(realtimeData);
      final userRef = realtime.ref('users/$uid');
      final snapshot = await userRef.get().timeout(const Duration(seconds: 3));
      if (snapshot.exists) {
        await userRef.update(sanitizedData).timeout(const Duration(seconds: 3));
      } else {
        await userRef.set(sanitizedData).timeout(const Duration(seconds: 3));
      }
    } catch (e) {
      debugPrint('[FirebaseService] Realtime profile write timeout/error: $e');
    }
  }

  static Future<void> updateUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    if (_app == null) return;
    if (data.isEmpty) return;
    final updateWithTimestamp = <String, dynamic>{
      ...data,
      'updated_at': FieldValue.serverTimestamp(),
    };
    try {
      await firestore
          .collection('users')
          .doc(uid)
          .set(updateWithTimestamp, SetOptions(merge: true))
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Firestore updateUserProfile error: $e');
    }
    try {
      await _saveUserProfileRealtime(uid: uid, data: data);
    } catch (e) {
      debugPrint('Realtime profile update failed: $e');
    }
  }

  static Future<void> saveStreakData({
    required String uid,
    required int streakCount,
    required int bestStreak,
    required String? lastCheckInDate,
    required List<String> milestonesReached,
    List<String>? completedChallenges,
    String? quickNotes,
  }) async {
    final streakUpdate = {
      'streak_count': streakCount,
      'best_streak': bestStreak,
      'last_check_in_date': lastCheckInDate,
      'streak_milestones_reached': milestonesReached,
      'daily_challenges_completed': completedChallenges ?? <String>[],
      'quick_notes': quickNotes ?? '',
    };

    await firestore.collection('streaks').doc(uid).set({
      'uid': uid,
      ...streakUpdate,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).timeout(const Duration(seconds: 4)).catchError((e) {
      debugPrint('Streak data save warning: $e');
      return null;
    });

    await updateUserProfile(uid: uid, data: streakUpdate);
  }

  static final Map<String, Map<String, dynamic>> _userProfileMemoryCache = {};

  static Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    if (!isAvailable || uid.isEmpty) return null;

    // Check fast in-memory cache first
    if (_userProfileMemoryCache.containsKey(uid) && _userProfileMemoryCache[uid] != null) {
      return _userProfileMemoryCache[uid];
    }

    try {
      final doc = await firestore.collection('users').doc(uid).get().timeout(const Duration(seconds: 4));
      if (doc.exists && doc.data() != null) {
        final data = Map<String, dynamic>.from(doc.data()!);
        _userProfileMemoryCache[uid] = data;
        return data;
      }
    } catch (e) {
      debugPrint('Error getting user profile from firestore (trying cache & RTDB): $e');
      try {
        final cachedDoc = await firestore.collection('users').doc(uid).get(const GetOptions(source: Source.cache));
        if (cachedDoc.exists && cachedDoc.data() != null) {
          final data = Map<String, dynamic>.from(cachedDoc.data()!);
          _userProfileMemoryCache[uid] = data;
          return data;
        }
      } catch (_) {}
    }

    // Fallback: Realtime Database 'users/$uid'
    try {
      final snap = await realtime.ref('users/$uid').get().timeout(const Duration(seconds: 3));
      if (snap.exists && snap.value is Map) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        _userProfileMemoryCache[uid] = data;
        return data;
      }
    } catch (e) {
      debugPrint('Realtime DB user profile fallback error: $e');
    }

    return null;
  }

  static Future<String> uploadAvatar({
    required String uid,
    required File file,
    required String fileName,
  }) async {
    // 1. Primary: Standalone Storage API Gateway (Vercel Blob Microservice)
    try {
      final bytes = await file.readAsBytes();
      final gatewayUrl = await StorageApiService.instance.uploadProfilePicture(
        bytes: bytes,
        userId: uid,
        fileName: fileName,
      );
      if (gatewayUrl != null && gatewayUrl.isNotEmpty) {
        return gatewayUrl;
      }
    } catch (e) {
      debugPrint('[FirebaseService] Gateway avatar upload notice: $e');
    }

    // 2. Secondary: Direct Multi-Vault Cloudinary Pipeline
    try {
      final cdnUrl = await CloudinaryStorageService.instance.uploadImage(
        file: file,
        folder: 'nexchat-avatars',
      );
      if (cdnUrl.isNotEmpty) {
        return cdnUrl;
      }
    } catch (e) {
      debugPrint('[FirebaseService] Cloudinary avatar upload notice: $e');
    }

    // 3. Tertiary tier: Direct Vercel Blob Profile Vault
    try {
      final blobUrl = await VercelBlobService.instance.uploadAvatar(
        file: file,
        uid: uid,
      );
      if (blobUrl != null && blobUrl.isNotEmpty) {
        return blobUrl;
      }
    } catch (e) {
      debugPrint('[FirebaseService] Vercel Blob avatar notice: $e');
    }

    // 4. Final fallback: Firebase Storage
    try {
      final ref = storage.ref().child('avatars').child(uid).child(fileName);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('[FirebaseService] Storage fallback error: $e');
      rethrow;
    }
  }

  static Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? username,
    String? photoUrl,
    int? age,
  }) async {
    final data = <String, dynamic>{};
    if (displayName != null && displayName.trim().isNotEmpty) {
      data['name'] = displayName.trim();
      data['displayName'] = displayName.trim();
      try {
        await auth.currentUser?.updateDisplayName(displayName.trim());
      } catch (_) {}
    }
    if (username != null && username.trim().isNotEmpty) {
      data['username'] = username.trim();
    }
    if (photoUrl != null && photoUrl.isNotEmpty) {
      data['photo_url'] = photoUrl;
      data['profilePic'] = photoUrl;
      data['profilePicUrl'] = photoUrl;
      try {
        await auth.currentUser?.updatePhotoURL(photoUrl);
      } catch (_) {}
    }
    if (age != null) {
      data['age'] = age;
    }
    if (data.isNotEmpty) {
      await updateUserProfile(uid: uid, data: data);
    }
  }

  static Future<Map<String, dynamic>?> ensureCurrentUserProfile() async {
    final user = auth.currentUser;
    if (user == null) return null;

    try {
      final existing = await getUserProfile(user.uid);
      final rawName = existing?['name']?.toString() ?? user.displayName ?? '';
      final rawUsername = existing?['username']?.toString() ??
          user.displayName ??
          user.email?.split('@').first ??
          'NEX User';
      final rawEmail = existing?['email']?.toString() ?? user.email ?? '';

      if (existing == null || rawName.isEmpty || rawUsername.isEmpty || rawEmail.isEmpty) {
        await saveUserProfile(
          uid: user.uid,
          email: rawEmail.isNotEmpty ? rawEmail : (user.email ?? ''),
          username: rawUsername.isNotEmpty ? rawUsername : 'NEX User',
          displayName: rawName.isNotEmpty ? rawName : rawUsername,
          photoUrl: existing?['photo_url']?.toString() ?? user.photoURL ?? '',
          tokenBalance: (existing?['token_balance'] as int?) ?? 2000,
          dailyBonusClaimed: existing?['daily_bonus_claimed'] == true,
        );
        return {
          'id': user.uid,
          'uid': user.uid,
          'email': rawEmail.isNotEmpty ? rawEmail : (user.email ?? ''),
          'username': rawUsername.isNotEmpty ? rawUsername : 'NEX User',
          'name': rawName.isNotEmpty ? rawName : rawUsername,
          'photo_url': existing?['photo_url']?.toString() ?? user.photoURL ?? '',
          'token_balance': (existing?['token_balance'] as int?) ?? 2000,
          'isOnline': true,
        };
      }

      return {
        'id': user.uid,
        'uid': user.uid,
        'isOnline': true,
        ...existing,
      };
    } catch (e) {
      debugPrint('[FirebaseService] ensureCurrentUserProfile error: $e');
      return {
        'id': user.uid,
        'uid': user.uid,
        'email': user.email ?? '',
        'username': user.displayName ?? user.email?.split('@').first ?? 'NEX User',
        'name': user.displayName ?? user.email?.split('@').first ?? 'NEX User',
        'photo_url': user.photoURL ?? '',
        'isOnline': true,
      };
    }
  }
}

