import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class MusicNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  static Future<void> showNowPlaying({required String title, required String artist}) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'music_player',
      'Music Player',
      channelDescription: 'Playback controls for the music player',
      importance: Importance.low,
      priority: Priority.low,
      playSound: false,
      showWhen: false,
      actions: [
        AndroidNotificationAction('play_pause', 'Play/Pause'),
        AndroidNotificationAction('next', 'Next'),
      ],
    );

    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      1001,
      title,
      artist,
      details,
    );
  }

  static Future<void> dismiss() async {
    await initialize();
    await _plugin.cancel(1001);
  }
}
