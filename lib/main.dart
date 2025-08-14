import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'firebase_messaging_service.dart'; // ✅ Import notification service
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/patient_dashboard.dart';

// ✅ Initialize Flutter Local Notifications
FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(); // ✅ Global key for navigation

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("🔹 Background Notification: ${message.notification?.title}");
}

void setupFirebaseMessaging() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("🔔 Foreground Notification: ${message.notification?.title}");
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print("📲 Opened from Notification: ${message.notification?.title}");
  });

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );


  // ✅ Request Permission for Notifications
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print("✅ User granted permission for notifications");
  } else {
    print("❌ User denied or has not accepted notifications permission");
  }

  // ✅ Get FCM Token (For Sending Notifications)
  String? token = await messaging.getToken();
  print("FCM Token: $token");

  // ✅ Register Firebase Messaging Handler
  setupFirebaseMessaging();

  // ✅ Initialize Firebase Messaging Service
  FirebaseMessagingService().initialize();

  // ✅ Initialize Local Notifications
  initNotifications();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
      ],
      child: MyApp(),
    ),
  );
}

void initNotifications() {
  var androidInit = const AndroidInitializationSettings('@mipmap/ic_launcher');
  var iosInit = const DarwinInitializationSettings();
  var initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

  notificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (response) {
      print("🔔 Notification clicked!");
      navigatorKey.currentState?.pushNamed('/patient_dashboard'); // ✅ Navigate to dashboard
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // ✅ Use navigator key
      debugShowCheckedModeBanner: false,
      title: 'Mobile Health App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: LoginScreen(),
      routes: {
        '/login': (context) => LoginScreen(),
        '/patient_dashboard': (context) => PatientDashboard(),
      },
    );
  }
}