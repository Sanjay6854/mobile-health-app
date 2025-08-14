import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HealthRecordsScreen extends StatelessWidget {
  final String patientId;

  HealthRecordsScreen({required this.patientId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Health Records")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('patients')
            .doc(patientId)
            .collection('health_records')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .snapshots(), // 🔥 Listens for real-time updates
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator()); // ⏳ Loading indicator
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No health records available")); // ❌ No records found
          }

          var healthData = snapshot.data!.docs.first.data() as Map<String, dynamic>;

          return Padding(
            padding: EdgeInsets.all(16.0),
            child: Card(
              elevation: 3,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("🩸 Blood Pressure: ${healthData['blood_pressure']}", style: TextStyle(fontSize: 18)),
                    Text("🍬 Sugar Level: ${healthData['sugar_level']}", style: TextStyle(fontSize: 18)),
                    Text("💓 Heart Rate: ${healthData['heart_rate']}", style: TextStyle(fontSize: 18)),
                    SizedBox(height: 10),
                    Text(
                      "📅 Last Updated: ${healthData['timestamp'] != null ? healthData['timestamp'].toDate().toString() : 'N/A'}",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
