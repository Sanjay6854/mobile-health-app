import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart' as auth;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> showNotification(String title, String body) async {
    var androidDetails = const AndroidNotificationDetails(
      'channelId', 'channelName',
      importance: Importance.high,
      priority: Priority.high,
    );

    var notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      0, // Notification ID
      title,  // Notification Title
      body,   // Notification Message
      notificationDetails,
    );
  }


  // ✅ Initialize Local Notifications
  static void initialize() {
    const AndroidInitializationSettings androidInitializationSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
    InitializationSettings(android: androidInitializationSettings);

    _notificationsPlugin.initialize(initializationSettings);
  }

  // ✅ Store Scheduled Notifications in Firestore
  Future<void> scheduleNotification(String userId, String title, String body) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'timestamp': Timestamp.now(),
      });
      print("✅ Notification scheduled for user: $userId");
    } catch (e) {
      print("❌ Error scheduling notification: $e");
    }
  }

  // ✅ Send Notification to Doctor Using FCM HTTP v1 API
  static Future<void> sendNotification(String token, String title, String body) async {
    final serviceAccount = await rootBundle.loadString('assets/service-account.json');
    final Map<String, dynamic> credentials = json.decode(serviceAccount);
    final String projectId = credentials['project_id'];

    final String endpoint =
        "https://fcm.googleapis.com/v1/projects/$projectId/messages:send";

    final String accessToken = await _getAccessToken();

    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
        body: jsonEncode({
          "message": {
            "token": token,
            "notification": {
              "title": title,
              "body": body,
            },
            "data": {
              "click_action": "FLUTTER_NOTIFICATION_CLICK",
            }
          }
        }),
      );

      if (response.statusCode == 200) {
        print("✅ Notification sent successfully!");
      } else {
        print("❌ Failed to send notification: ${response.body}");
      }
    } catch (e) {
      print("❌ Error sending notification: $e");
    }
  }

  // ✅ Fetch scheduled reminders & send notifications to patients
  Future<void> sendMedicationReminders() async {
    try {
      // Get current time
      Timestamp currentTime = Timestamp.now();

      // Fetch active medication reminders from Firestore
      QuerySnapshot reminderSnapshot = await _firestore
          .collection('medicine_reminders')
          .where('status', isEqualTo: 'active')
          .where('startDate', isLessThanOrEqualTo: currentTime) // Send reminders for today
          .get();

      for (QueryDocumentSnapshot doc in reminderSnapshot.docs) {
        Map<String, dynamic> reminder = doc.data() as Map<String, dynamic>;

        String patientId = reminder['patientId'];
        String medicine = reminder['medicine'];
        String timing = reminder['timing'];

        // Get patient's FCM token
        DocumentSnapshot patientSnapshot = await _firestore.collection('users').doc(patientId).get();
        if (patientSnapshot.exists) {
          String? fcmToken = patientSnapshot['fcmToken'];

          if (fcmToken != null) {
            // Send notification to the patient
            await sendNotification(
                fcmToken,
                "Medication Reminder 💊",
                "Take your medicine: $medicine at $timing."
            );
            print("✅ Reminder sent to patient: $patientId");
          } else {
            print("❌ Patient has no FCM Token.");
          }
        }
      }
    } catch (e) {
      print("❌ Error sending medication reminders: $e");
    }
  }

  // ✅ Get Doctor's Token & Send Notification
  Future<void> sendAppointmentNotification(String doctorId, String title, String body) async {
    try {
      DocumentSnapshot doctorSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(doctorId)
          .get();

      if (doctorSnapshot.exists) {
        String? fcmToken = doctorSnapshot['fcmToken'];

        if (fcmToken != null) {
          await sendNotification(fcmToken, title, body);
          print("✅ Notification sent to Doctor: $doctorId");
        } else {
          print("❌ Doctor has no FCM Token.");
        }
      }
    } catch (e) {
      print("❌ Error sending doctor notification: $e");
    }
  }

  // ✅ Generate Access Token using Service Account
  static Future<String> _getAccessToken() async {
    try {
      final serviceAccount = await rootBundle.loadString('assets/service-account.json');
      final Map<String, dynamic> credentials = json.decode(serviceAccount);

      final accountCredentials = auth.ServiceAccountCredentials.fromJson(credentials);
      final List<String> scopes = ["https://www.googleapis.com/auth/firebase.messaging"];

      final client = await auth.clientViaServiceAccount(accountCredentials, scopes);
      return client.credentials.accessToken.data;
    } catch (e) {
      throw Exception("❌ Error getting access token: $e");
    }
  }

  static Future<String> _generateJWT(Map<String, dynamic> credentials) async {
    final accountCredentials = auth.ServiceAccountCredentials.fromJson(credentials);
    final scopes = ["https://www.googleapis.com/auth/firebase.messaging"];

    final client = await auth.clientViaServiceAccount(accountCredentials, scopes);
    return client.credentials.accessToken.data;
  }
}
