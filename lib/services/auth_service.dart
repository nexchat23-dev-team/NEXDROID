import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../providers/token_provider.dart';
import 'firebase_service.dart';
import 'upload_progress_service.dart';

class AuthService extends ChangeNotifier {
  String? _lastError;
  String? _activeUid;

  static String resolveDisplayName({
    String? name,
    String? username,
    String? email,
  }) {
    final trimmedName = name?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) return trimmedName;

    final trimmedUsername = username?.trim();
    if (trimmedUsername != null && trimmedUsername.isNotEmpty) return trimmedUsername;

    final trimmedEmail = email?.trim();
    if (trimmedEmail != null && trimmedEmail.isNotEmpty) {
      final localPart = trimmedEmail.split('@').first.trim();
      if (localPart.isNotEmpty) return localPart;
    }

    return 'NEX User';
  }

  User? get user => FirebaseService.auth.currentUser;
  bool get isLoggedIn => user != null;
  String? get lastError => _lastError;
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? get userProfile => _userProfile;

  AuthService() {
    FirebaseService.auth.authStateChanges().listen((user) {
      if (user != null) {
        _activeUid = user.uid;
        unawaited(FirebaseService.setUserPresence(uid: user.uid, isOnline: true));
      } else if (_activeUid != null) {
        unawaited(FirebaseService.setUserPresence(uid: _activeUid!, isOnline: false));
        _activeUid = null;
      }
      notifyListeners();
    });
  }

  // Secure storage for biometric quick-sign
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> saveCredentials(String email, String password) async {
    try {
      await _secureStorage.write(key: 'saved_email', value: email);
      await _secureStorage.write(key: 'saved_password', value: password);
    } catch (e) {
      debugPrint('Error saving credentials: $e');
    }
  }

  Future<void> clearSavedCredentials() async {
    try {
      await _secureStorage.delete(key: 'saved_email');
      await _secureStorage.delete(key: 'saved_password');
    } catch (e) {
      debugPrint('Error clearing saved credentials: $e');
    }
  }

  Future<Map<String, String>?> getSavedCredentials() async {
    try {
      final email = await _secureStorage.read(key: 'saved_email');
      final password = await _secureStorage.read(key: 'saved_password');
      if (email != null && password != null) {
        return {'email': email, 'password': password};
      }
    } catch (e) {
      debugPrint('Error reading saved credentials: $e');
    }
    return null;
  }

  /// Attempts to sign in using saved credentials. Returns true on success.
  Future<bool> signInWithSavedCredentials() async {
    try {
      final creds = await getSavedCredentials();
      if (creds == null) return false;
      await signIn(creds['email']!, creds['password']!);
      return true;
    } catch (e) {
      debugPrint('Error signing in with saved credentials: $e');
      return false;
    }
  }

  Future<void> _ensureFirebaseReady() async {
    await FirebaseService.initialize();
  }

  Future<void> signIn(String email, String password) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Email and password are required.');
      }

      await _ensureFirebaseReady();
      await FirebaseService.signIn(email, password);
      final signedInUser = FirebaseService.auth.currentUser;
      if (signedInUser != null) {
        _activeUid = signedInUser.uid;
        unawaited(FirebaseService.setUserPresence(uid: signedInUser.uid, isOnline: true));
        unawaited(_ensureUserDocument(signedInUser));
        unawaited(fetchUserProfile(user: signedInUser));
      }
      _lastError = null;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      _lastError = e.message;
      throw Exception(_lastError);
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    }
  }

  Future<void> fetchUserProfile({User? user}) async {
    try {
      final u = user ?? FirebaseService.auth.currentUser;
      if (u == null) {
        _userProfile = null;
        notifyListeners();
        return;
      }

      final data = await FirebaseService.getUserProfile(u.uid);
      if (data != null) {
        _userProfile = Map<String, dynamic>.from(data);
      } else {
        _userProfile = null;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }
  }

  Future<void> syncFirebaseTokenState(TokenProvider tokenProvider) async {
    final user = FirebaseService.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await FirebaseService.getUserProfile(user.uid);
      final remoteBalanceValue = profile?['token_balance'];
      final hasRemoteBalance = profile?.containsKey('token_balance') ?? false;
      final remoteBalance = remoteBalanceValue is int
          ? remoteBalanceValue
          : int.tryParse(remoteBalanceValue?.toString() ?? '') ?? 2000;
      final remoteBonusClaimed = profile?['daily_bonus_claimed'] is bool
          ? profile!['daily_bonus_claimed'] as bool
          : false;

      final balance = hasRemoteBalance
          ? remoteBalance
          : tokenProvider.balance > 0
              ? tokenProvider.balance
              : 2000;

      tokenProvider.setBalance(balance);
      await tokenProvider.setDailyBonusClaimed(remoteBonusClaimed);
      await tokenProvider.syncStreakState(profile);
    } catch (e) {
      debugPrint('Error syncing token state from Firebase: $e');
    }
  }

  Future<void> signUp(String email, String password, String username,
      {String? displayName, int? age, String? ipAddress, String? country, String? referralCode}) async {
    try {
      if (email.isEmpty || password.isEmpty || username.isEmpty) {
        throw Exception('Email, password, and username are required.');
      }

      await _ensureFirebaseReady();
      await FirebaseService.signUp(email, password);

      User? user = FirebaseService.auth.currentUser;
      if (user == null) {
        await Future.delayed(const Duration(milliseconds: 300));
        user = FirebaseService.auth.currentUser;
      }

      if (user != null) {
        _activeUid = user.uid;
        unawaited(FirebaseService.setUserPresence(uid: user.uid, isOnline: true));
        unawaited(_createUserDocument(
          user,
          username: username,
          displayName: displayName,
          age: age,
          ipAddress: ipAddress,
          country: country,
          referralCode: referralCode,
        ));
      }
      
      _lastError = null;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      _lastError = e.message;
      throw Exception(_lastError);
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    }
  }

  Future<void> _createUserDocument(User? user, {String? username, String? displayName, int? age, String? ipAddress, String? country, String? referralCode}) async {
    if (user == null) return;

    final resolvedName = displayName ?? AuthService.resolveDisplayName(
      name: user.displayName,
      username: username ?? user.displayName,
      email: user.email,
    );

    // Let any errors bubble up so registration fails visibly if Firestore write is blocked
    await FirebaseService.saveUserProfile(
      uid: user.uid,
      email: user.email ?? '',
      username: username ?? user.displayName ?? user.email?.split('@').first ?? 'NEX User',
      displayName: resolvedName,
      photoUrl: '',
      tokenBalance: 2000,
      dailyBonusClaimed: false,
      age: age,
      ipAddress: ipAddress,
      country: country,
    );
    await fetchUserProfile(user: user);
  }

  Future<int> syncPendingReferralRewards(TokenProvider tokenProvider) async {
    final user = FirebaseService.auth.currentUser;
    if (user == null) return 0;

    try {
      final data = await FirebaseService.getUserProfile(user.uid);
      final pendingTokens = (data?['pending_referral_tokens'] as int?) ?? 0;
      if (pendingTokens > 0) {
        tokenProvider.addTokens(pendingTokens);
      }
      return pendingTokens;
    } catch (e) {
      debugPrint('Error syncing referral rewards: $e');
      return 0;
    }
  }

  Future<bool> _ensureUserDocument(User? user) async {
    try {
      if (user == null) return false;
      final existing = await FirebaseService.getUserProfile(user.uid);

      if (existing == null) {
        await FirebaseService.saveUserProfile(
          uid: user.uid,
          email: user.email ?? '',
          username: user.displayName ?? user.email?.split('@').first ?? 'NEX User',
          displayName: user.displayName,
          photoUrl: '',
          tokenBalance: 2000,
          dailyBonusClaimed: false,
        );
        await fetchUserProfile(user: user);
        return true;
      }

      final updated = <String, dynamic>{};
      final data = Map<String, dynamic>.from(existing);
      final displayName = AuthService.resolveDisplayName(
        name: data['name']?.toString(),
        username: data['username']?.toString(),
        email: user.email,
      );
      if (data['name'] == null || data['name'].toString().isEmpty) {
        updated['name'] = displayName;
      }
      if (data['username'] == null || data['username'].toString().isEmpty) {
        updated['username'] = displayName;
      }
      if (data['email'] == null || data['email'].toString().isEmpty) {
        updated['email'] = user.email ?? '';
      }
      if (data['game_genres'] == null || data['game_genres'] is! List || (data['game_genres'] as List).isEmpty) {
        updated['game_genres'] = FirebaseService.defaultGameGenres();
      }
      if (data['game_badges'] == null || data['game_badges'] is! List || (data['game_badges'] as List).isEmpty) {
        updated['game_badges'] = FirebaseService.defaultGameBadges();
      }
      if (updated.isNotEmpty) {
        await FirebaseService.updateUserProfile(uid: user.uid, data: updated);
        await fetchUserProfile(user: user);
      }
      return false;
    } catch (e) {
      debugPrint('Error ensuring user document: $e');
      // Surface Firestore write errors so sign-in/registration callers can handle them.
      rethrow;
    }
  }

  Future<String?> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final user = FirebaseService.auth.currentUser;
    if (user == null || bytes.isEmpty) return null;

    final uploadId = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
    final uploadService = UploadProgressService();
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = '${user.uid}/avatar_${DateTime.now().millisecondsSinceEpoch}_$safeName';

    try {
      uploadService.startUpload(
        id: uploadId,
        fileName: 'Profile: $safeName',
        totalBytes: bytes.length,
      );

      uploadService.updateProgress(
        id: uploadId,
        bytesUploaded: bytes.length ~/ 4,
        totalBytes: bytes.length,
      );

      final tempFile = File('${Directory.systemTemp.path}/$path');
      // Ensure parent directories exist on Android before writing the temporary file
      await tempFile.parent.create(recursive: true);
      await tempFile.writeAsBytes(bytes);
      final url = await FirebaseService.uploadAvatar(uid: user.uid, file: tempFile, fileName: safeName);
      await updateProfile(photoUrl: url);

      uploadService.updateProgress(
        id: uploadId,
        bytesUploaded: bytes.length,
        totalBytes: bytes.length,
      );
      uploadService.completeUpload(id: uploadId);
      return url;
    } catch (e) {
      debugPrint('Error uploading avatar: $e');
      uploadService.failUpload(id: uploadId, error: 'Failed to upload profile picture');
      rethrow;
    }
  }

  Future<void> updateProfile({String? displayName, String? photoUrl, String? username, int? age}) async {
    final user = FirebaseService.auth.currentUser;
    if (user == null) return;

    await FirebaseService.updateProfile(
      uid: user.uid,
      displayName: displayName,
      username: username,
      photoUrl: photoUrl,
      age: age,
    );
    await fetchUserProfile(user: user);
    notifyListeners();
  }

  Future<void> updateProfileData({
    String? role,
    String? modeTrack,
    String? modeLevel,
    String? modeTopic,
    int? age,
    String? ipAddress,
    String? country,
  }) async {
    final user = FirebaseService.auth.currentUser;
    if (user == null) return;

    final data = <String, dynamic>{};
    if (role != null) data['role'] = role;
    if (modeTrack != null) data['mode_track'] = modeTrack;
    if (modeLevel != null) data['mode_level'] = modeLevel;
    if (modeTopic != null) data['mode_topic'] = modeTopic;
    if (age != null) data['age'] = age;
    if (ipAddress != null) data['ip_address'] = ipAddress;
    if (country != null) data['country'] = country;

    if (data.isEmpty) return;

    await FirebaseService.updateUserProfile(uid: user.uid, data: data);
    await fetchUserProfile(user: user);
    notifyListeners();
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await FirebaseService.getUserProfile(userId);
      if (response == null) return null;
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      return null;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      if (email.isEmpty) {
        throw Exception('Email is required.');
      }
      await _ensureFirebaseReady();
      await FirebaseService.auth.sendPasswordResetEmail(email: email);
      _lastError = null;
    } on FirebaseAuthException catch (e) {
      _lastError = e.message;
      throw Exception(_lastError);
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    }
  }

  Future<bool> signInWithOAuthProvider(String provider) async {
    try {
      await _ensureFirebaseReady();
      final p = provider.trim().toLowerCase();
      if (p == 'google') {
        return await signInWithGoogle();
      }
      if (p == 'github') {
        final githubProvider = OAuthProvider('github.com');
        githubProvider.addScope('read:user');
        githubProvider.addScope('user:email');
        githubProvider.setCustomParameters({'allow_signup': 'true'});
        final credential = await FirebaseService.auth.signInWithProvider(githubProvider);
        final user = credential.user;
        if (user == null) return false;
        _activeUid = user.uid;
        unawaited(FirebaseService.setUserPresence(uid: user.uid, isOnline: true));
        unawaited(_ensureUserDocument(user));
        unawaited(fetchUserProfile(user: user));
        _lastError = null;
        notifyListeners();
        return true;
      }
      if (p == 'microsoft') {
        final microsoftProvider = OAuthProvider('microsoft.com');
        microsoftProvider.addScope('User.Read');
        final credential = await FirebaseService.auth.signInWithProvider(microsoftProvider);
        final user = credential.user;
        if (user == null) return false;
        _activeUid = user.uid;
        unawaited(FirebaseService.setUserPresence(uid: user.uid, isOnline: true));
        unawaited(_ensureUserDocument(user));
        unawaited(fetchUserProfile(user: user));
        _lastError = null;
        notifyListeners();
        return true;
      }
      if (p == 'discord') {
        final discordProvider = OAuthProvider('discord.com');
        discordProvider.addScope('identify');
        discordProvider.addScope('email');
        final credential = await FirebaseService.auth.signInWithProvider(discordProvider);
        final user = credential.user;
        if (user == null) return false;
        _activeUid = user.uid;
        unawaited(FirebaseService.setUserPresence(uid: user.uid, isOnline: true));
        unawaited(_ensureUserDocument(user));
        unawaited(fetchUserProfile(user: user));
        _lastError = null;
        notifyListeners();
        return true;
      }
      if (p == 'twitter') {
        final twitterProvider = OAuthProvider('twitter.com');
        final credential = await FirebaseService.auth.signInWithProvider(twitterProvider);
        final user = credential.user;
        if (user == null) return false;
        _activeUid = user.uid;
        unawaited(FirebaseService.setUserPresence(uid: user.uid, isOnline: true));
        unawaited(_ensureUserDocument(user));
        unawaited(fetchUserProfile(user: user));
        _lastError = null;
        notifyListeners();
        return true;
      }
      if (p == 'apple') {
        final appleProvider = OAuthProvider('apple.com');
        appleProvider.addScope('email');
        appleProvider.addScope('name');
        final credential = await FirebaseService.auth.signInWithProvider(appleProvider);
        final user = credential.user;
        if (user == null) return false;
        _activeUid = user.uid;
        unawaited(FirebaseService.setUserPresence(uid: user.uid, isOnline: true));
        unawaited(_ensureUserDocument(user));
        unawaited(fetchUserProfile(user: user));
        _lastError = null;
        notifyListeners();
        return true;
      }
      throw Exception('OAuth provider "$provider" is coming soon. Please sign in with Google, GitHub, Discord, or Email.');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'canceled' ||
          e.code == 'cancelled' ||
          e.code == 'web-context-cancelled') {
        return false;
      }
      _lastError = e.message;
      throw Exception(_lastError);
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('cancel') || errStr.contains('canceled') || errStr.contains('cancelled') || errStr.contains('popup_closed')) {
        return false;
      }
      _lastError = e.toString();
      rethrow;
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      await _ensureFirebaseReady();

      // On Web or Desktop where native GoogleSignIn plugin might not be configured,
      // fallback directly to Firebase OAuth Provider
      if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        final userCredential = await FirebaseService.auth.signInWithProvider(googleProvider);
        final user = userCredential.user;
        if (user == null) return false;

        _activeUid = user.uid;
        unawaited(FirebaseService.setUserPresence(uid: user.uid, isOnline: true));
        unawaited(_ensureUserDocument(user));
        unawaited(fetchUserProfile(user: user));
        _lastError = null;
        notifyListeners();
        return true;
      }

      // Mobile (Android / iOS): Try GoogleSignIn plugin with automatic fallback
      try {
        final googleSignIn = GoogleSignIn(
          scopes: ['email', 'profile'],
        );
        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          // User closed/cancelled the Google account picker
          return false;
        }

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential = await FirebaseService.auth.signInWithCredential(credential);
        final user = userCredential.user;
        if (user == null) return false;

        _activeUid = user.uid;
        unawaited(FirebaseService.setUserPresence(uid: user.uid, isOnline: true));
        unawaited(_ensureUserDocument(user));
        unawaited(fetchUserProfile(user: user));
        _lastError = null;
        notifyListeners();
        return true;
      } catch (pluginError) {
        final errLower = pluginError.toString().toLowerCase();
        if (errLower.contains('cancel') || errLower.contains('canceled') || errLower.contains('cancelled')) {
          return false;
        }

        // If MissingPluginException or ApiException: 10, try Firebase Auth Provider fallback
        debugPrint('Native GoogleSignIn exception: $pluginError. Attempting Provider fallback...');
        try {
          final googleProvider = GoogleAuthProvider();
          final userCredential = await FirebaseService.auth.signInWithProvider(googleProvider);
          final user = userCredential.user;
          if (user == null) return false;

          _activeUid = user.uid;
          unawaited(FirebaseService.setUserPresence(uid: user.uid, isOnline: true));
          unawaited(_ensureUserDocument(user));
          unawaited(fetchUserProfile(user: user));
          _lastError = null;
          notifyListeners();
          return true;
        } catch (fallbackError) {
          if (errLower.contains('10') || errLower.contains('sign_in_failed') || errLower.contains('apiexception')) {
            throw Exception('Google Sign-In failed (ApiException 10). Please ensure the SHA-1 fingerprint is added to your Firebase Console project settings.');
          }
          rethrow;
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'canceled' ||
          e.code == 'cancelled' ||
          e.code == 'web-context-cancelled') {
        return false;
      }
      _lastError = e.message;
      throw Exception(_lastError);
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('cancel') || errStr.contains('canceled') || errStr.contains('cancelled')) {
        return false;
      }
      _lastError = e.toString();
      rethrow;
    }
  }

  Future<String> sendPhoneVerificationCode(String phoneNumber) async {
    await _ensureFirebaseReady();
    final completer = Completer<String>();
    await FirebaseService.auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) async {
        try {
          final result = await FirebaseService.auth.signInWithCredential(credential);
          final user = result.user;
          if (user != null) {
            _activeUid = user.uid;
            unawaited(FirebaseService.setUserPresence(uid: user.uid, isOnline: true));
            unawaited(_ensureUserDocument(user));
            unawaited(fetchUserProfile(user: user));
            if (!completer.isCompleted) completer.complete('');
          }
        } catch (error) {
          if (!completer.isCompleted) completer.completeError(error);
        }
      },
      verificationFailed: (error) {
        if (!completer.isCompleted) completer.completeError(error);
      },
      codeSent: (verificationId, _) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
    );
    return completer.future;
  }

  Future<void> signInWithPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {
    await _ensureFirebaseReady();
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final result = await FirebaseService.auth.signInWithCredential(credential);
    final user = result.user;
    if (user == null) throw Exception('Phone sign-in failed: no user returned');
    _activeUid = user.uid;
    unawaited(FirebaseService.setUserPresence(uid: user.uid, isOnline: true));
    unawaited(_ensureUserDocument(user));
    unawaited(fetchUserProfile(user: user));
    _lastError = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      final uid = FirebaseService.auth.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        unawaited(FirebaseService.setUserPresence(uid: uid, isOnline: false));
      }
      await FirebaseService.auth.signOut();
      _activeUid = null;
      _lastError = null;
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    }
  }
}
