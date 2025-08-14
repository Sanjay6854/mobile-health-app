import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("📩 Background Notification: ${message.notification?.title}");
}

class FirebaseMessagingService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Request permission for notifications
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize Local Notifications
    const AndroidInitializationSettings androidInitSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initSettings =
    InitializationSettings(android: androidInitSettings);

    await _flutterLocalNotificationsPlugin.initialize(initSettings);

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Push notifications enabled!');

      // Get the FCM token for this device
      String? token = await _firebaseMessaging.getToken();
      print("📌 FCM Token: $token");

      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print("📩 Foreground Notification: ${message.notification?.title}");
        _showNotification(message);
      });

      // Handle notification taps when app is terminated
      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null) {
          print("🚀 App opened from terminated state by notification.");
        }
      });

      // Handle notification taps when app is in the background
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        print("📲 Notification clicked! Data: ${message.data}");
      });
    } else {
      print("❌ Push notifications NOT enabled!");
    }
  }

  Future<void> _showNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default Channel',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _flutterLocalNotificationsPlugin.show(
      0, // Notification ID
      message.notification?.title,
      message.notification?.body,
      details,
    );
  }
}
