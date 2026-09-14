import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  Future<void> init() async {
    // Request permissions
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
      await _saveDeviceToken();
    } else {
      debugPrint('User declined or has not accepted permission');
    }

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification}');
      }
    });
  }

  Future<void> _saveDeviceToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      String? token = await _messaging.getToken();
      if (token != null) {
        await _firestore
            .collection('deviceTokens')
            .doc(user.uid)
            .collection('tokens')
            .doc(token)
            .set({
          'token': token,
          'createdAt': FieldValue.serverTimestamp(),
          'platform': defaultTargetPlatform.toString(),
        });
      }

      _messaging.onTokenRefresh.listen((newToken) async {
        await _firestore
            .collection('deviceTokens')
            .doc(user.uid)
            .collection('tokens')
            .doc(newToken)
            .set({
          'token': newToken,
          'createdAt': FieldValue.serverTimestamp(),
          'platform': defaultTargetPlatform.toString(),
        });
      });
    } catch (e) {
      debugPrint('Failed to save device token: $e');
    }
  }

  Future<void> sendNotificationToUser(String targetUserId, String title, String body, Map<String, dynamic>? data) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _firestore.collection('notifications').add({
        'userId': targetUserId,
        'senderId': currentUser.uid,
        'title': title,
        'body': body,
        'data': data ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      debugPrint('Failed to create notification document: $e');
    }
  }

  Stream<QuerySnapshot> getUserNotifications() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': true,
      });
    } catch (e) {
      debugPrint('Failed to mark notification as read: $e');
    }
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
}
