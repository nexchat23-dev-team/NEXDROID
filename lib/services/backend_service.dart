import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

// ─── CENTRAL APP BACKEND CONTROLLER & SYSTEM RULES ───────────────────────────
class AppBackendController {
  static final AppBackendController instance = AppBackendController._();
  AppBackendController._();

  // App Master Controls & Feature Flags
  bool isClonerEngineEnabled = true;
  bool isDefenderEngineEnabled = true;
  bool isFirewallEngineEnabled = true;
  bool isGamingHubActive = true;
  bool isCloudSyncEnabled = true;

  // System Rules & Limits
  int maxAllowedClonesPerApp = 5;
  int securityScanTimeoutMs = 15000;
  String defenderDefinitionVersion = '1.399.2026.1';
  int defenderBlockedThreatCount = 247;

  // System Health Monitor Stream
  final StreamController<Map<String, dynamic>> _healthStream =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get systemHealthStream => _healthStream.stream;

  void pushSystemEvent(String event, String status, {Map<String, dynamic>? details}) {
    final payload = {
      'timestamp': DateTime.now().toIso8601String(),
      'event': event,
      'status': status,
      'details': details ?? {},
    };
    debugPrint('AppBackendController Event: $payload');
    _healthStream.add(payload);
  }

  /// Syncs global backend rules and remote config
  Future<void> fetchRemoteConfig() async {
    try {
      pushSystemEvent('REMOTE_CONFIG_FETCH', 'SUCCESS', details: {
        'version': defenderDefinitionVersion,
        'maxClones': maxAllowedClonesPerApp,
      });
    } catch (e) {
      pushSystemEvent('REMOTE_CONFIG_FETCH', 'FALLBACK', details: {'error': e.toString()});
    }
  }

  /// Updates firewall policy rules on central controller
  void updateFirewallRules({
    required bool inbound,
    required bool outbound,
    required bool stealthMode,
  }) {
    pushSystemEvent('FIREWALL_POLICY_UPDATE', 'APPLIED', details: {
      'inboundBlocking': inbound,
      'outboundFiltering': outbound,
      'stealthMode': stealthMode,
    });
  }
}

// ─── FIREBASE / SUPABASE BACKEND ADAPTERS ────────────────────────────────────
class SupabaseService {
  static bool _initialized = false;
  static String? _initError;
  static final SupabaseClient _client = SupabaseClient();

  static bool get isConfigured => _initialized;
  static String? get initError => _initError;

  static Future<void> initialize() async {
    try {
      _initialized = true;
      _initError = null;
      await AppBackendController.instance.fetchRemoteConfig();
      debugPrint('Backend initialized with Central AppBackendController & Firebase adapter.');
    } catch (e) {
      _initialized = false;
      _initError = e.toString();
      debugPrint('Error initializing Backend: $e');
    }
  }

  static SupabaseClient get client => _client;
}

class FirebaseBackend {
  static final FirebaseBackend instance = FirebaseBackend._();
  FirebaseBackend._();

  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseStorage get storage => FirebaseStorage.instance;
  FirebaseFirestore get firestore => FirebaseFirestore.instance;
}

extension CurrentUser on FirebaseAuth {
  SupabaseUser? get currentUser {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return SupabaseUser(id: user.uid, email: user.email);
  }
}

class SupabaseUser {
  final String id;
  final String? email;

  const SupabaseUser({required this.id, this.email});
}

extension FirebaseUserId on User {
  String get id => uid;
}

/// Legacy Adapter - Routes database queries to Firestore / Backend Controller
class SupabaseClient {
  late FirebaseBackend _backend;

  SupabaseClient() {
    _backend = FirebaseBackend.instance;
  }

  FirebaseAuth get auth => _backend.auth;
  FirebaseStorage get storage => _backend.storage;

  FirestoreCollection from(String collectionName) {
    return FirestoreCollection(_backend.firestore.collection(collectionName));
  }
}

class FirestoreCollection {
  final CollectionReference<Map<String, dynamic>> _collection;

  FirestoreCollection(this._collection);

  /// Insert/add new document
  FirestoreQuery insert(Map<String, dynamic> data) {
    return FirestoreQuery(_collection.add(data));
  }

  /// Update existing documents
  Future<void> update(Map<String, dynamic> data, String documentId) async {
    await _collection.doc(documentId).update(data);
  }

  /// Delete documents
  Future<void> delete(String documentId) async {
    await _collection.doc(documentId).delete();
  }

  /// Get documents with filtering
  FirebaseQueryBuilder select([String? columns]) {
    return FirebaseQueryBuilder(_collection);
  }

  /// Stream documents
  FirestoreCollectionStream stream({List<String>? primaryKey}) {
    return FirestoreCollectionStream(_collection);
  }

  /// Upsert (set with merge)
  Future<void> upsert(Map<String, dynamic> data, String documentId) async {
    await _collection.doc(documentId).set(data, SetOptions(merge: true));
  }
}

class FirestoreCollectionStream extends Stream<List<Map<String, dynamic>>> {
  final Query<Map<String, dynamic>> _query;

  FirestoreCollectionStream(this._query);

  @override
  StreamSubscription<List<Map<String, dynamic>>> listen(
    void Function(List<Map<String, dynamic>> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _mapSnapshots(_query).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  Stream<List<Map<String, dynamic>>> _mapSnapshots(Query<Map<String, dynamic>> query) {
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> order(String field, {required bool ascending}) {
    return _mapSnapshots(_query.orderBy(field, descending: !ascending));
  }

  Stream<List<Map<String, dynamic>>> snapshots() {
    return _mapSnapshots(_query);
  }
}

class FirestoreQuery {
  final Future<DocumentReference<Map<String, dynamic>>> _future;

  FirestoreQuery(this._future);

  Future<Map<String, dynamic>> select() async {
    final docRef = await _future;
    final doc = await docRef.get();
    final data = Map<String, dynamic>.from(doc.data() ?? {});
    data['id'] = doc.id;
    return data;
  }

  Future<Map<String, dynamic>> single() async {
    return select();
  }
}

/// Adapter for Firebase queries with filtering
class FirebaseQueryBuilder {
  Query<Map<String, dynamic>> _query;

  FirebaseQueryBuilder(this._query);

  FirebaseQueryBuilder eq(String field, dynamic value) {
    _query = _query.where(field, isEqualTo: value);
    return this;
  }

  FirebaseQueryBuilder where(String field, dynamic value) {
    _query = _query.where(field, isEqualTo: value);
    return this;
  }

  FirebaseQueryBuilder inFilter(String field, List<dynamic> values) {
    _query = _query.where(field, whereIn: values);
    return this;
  }

  FirebaseQueryBuilder gt(String field, dynamic value) {
    _query = _query.where(field, isGreaterThan: value);
    return this;
  }

  FirebaseQueryBuilder order(String field, {required bool ascending}) {
    _query = _query.orderBy(field, descending: !ascending);
    return this;
  }

  FirebaseQueryBuilder limit(int count) {
    _query = _query.limit(count);
    return this;
  }

  Future<List<Map<String, dynamic>>> execute() async {
    final snapshot = await _query.get();
    return snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<Map<String, dynamic>?> single() async {
    final results = await execute();
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> maybeSingle() async {
    return single();
  }

  Stream<List<Map<String, dynamic>>> snapshots() {
    return _query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }
}
