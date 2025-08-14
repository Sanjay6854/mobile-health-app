import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mha1/screens/webrtc_helper.dart';
import 'package:mha1/screens/video_call_screen.dart';
import 'DoctorPatientList.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mha1/services/notification_service.dart';

class DoctorDashboard extends StatefulWidget {
  @override
  _DoctorDashboardState createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  final WebRTCService _webrtcService = WebRTCService();
  String? callId;
  Map<String, dynamic>? doctorData;
  Map<String, String> _patientNamesCache = {};
  TextEditingController _nameController = TextEditingController();
  TextEditingController _specialtyController = TextEditingController();
  bool _isEditingName = false; // Track editing state

  Future<void> sendPatientNotification(String patientId, String title, String body) async {
    try {
      DocumentSnapshot patientSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .get();

      if (patientSnapshot.exists) {
        String? fcmToken = patientSnapshot['fcmToken'];

        if (fcmToken != null && fcmToken.isNotEmpty) {
          await NotificationService.sendNotification(fcmToken, title, body);
          print("✅ Notification sent to Patient: $patientId");
        } else {
          print("❌ Patient has no FCM Token.");
        }
      }
    } catch (e) {
      print("❌ Error sending patient notification: $e");
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPatientHealthHistory(String patientId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('health_records')
          .doc(patientId)
          .collection('history')
          .orderBy('timestamp', descending: true)
          .get();

      List<Map<String, dynamic>> records = snapshot.docs.map((doc) {
        // Extract and parse blood pressure
        String bpRaw = doc["blood_pressure"].toString();
        double bp = 0;
        if (bpRaw.contains("/")) {
          bp = double.tryParse(bpRaw.split("/")[0]) ?? 0; // Take systolic value
        }

        return {
          "bp": bp,  // Now it correctly extracts BP
          "sugar": double.tryParse(doc["sugar_level"].toString()) ?? 0,
          "heart_rate": double.tryParse(doc["heart_rate"].toString()) ?? 0,
          "date": (doc["timestamp"] as Timestamp).toDate(),
        };
      }).toList();

      print("✅ Fetched Health Data: $records"); // Debugging

      return records;
    } catch (e) {
      print("❌ Error fetching patient history: $e");
      return [];
    }
  }

  Widget _buildHealthProgressGraph(List<Map<String, dynamic>> records) {
    if (records.isEmpty) {
      return Center(child: Text("⚠️ No health data available."));
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(seconds: 3),
      curve: Curves.easeInOutCubic,
      builder: (context, value, child) {
        return Container(
          height: 320,
          width: double.infinity,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)],
          ),
          child: LineChart(
            LineChartData(
              minY: 0,
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(value.toInt().toString(), style: TextStyle(fontSize: 12));
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      int index = value.toInt();
                      if (index >= 0 && index < records.length) {
                        final date = records[index]['date'] as DateTime;
                        return Text("${date.month}/${date.day}", style: TextStyle(fontSize: 10));
                      }
                      return Text('');
                    },
                  ),
                ),
              ),
              gridData: FlGridData(show: true),
              borderData: FlBorderData(show: true),
              lineBarsData: [
                _createAnimatedLine(records, 'bp', Colors.blueAccent, value, 0),
                _createAnimatedLine(records, 'sugar', Colors.redAccent, value, 0.2),
                _createAnimatedLine(records, 'heart_rate', Colors.green, value, 0.4),
              ],
            ),
          ),
        );
      },
    );
  }

  LineChartBarData _createAnimatedLine(
      List<Map<String, dynamic>> records, String key, Color color, double animValue, double delay) {
    // Apply stagger delay
    double adjustedValue = ((animValue - delay) / (1 - delay)).clamp(0.0, 1.0);

    int visibleCount = (records.length * adjustedValue).clamp(0, records.length).toInt();

    List<FlSpot> spots = records.asMap().entries
        .take(visibleCount)
        .map((entry) {
      int index = entry.key;
      double value = double.tryParse(entry.value[key]?.toString() ?? "0") ?? 0;
      return FlSpot(index.toDouble(), value);
    }).toList();

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.3,
      color: color,
      barWidth: 4,
      isStrokeCapRound: true,
      shadow: Shadow(blurRadius: 6, color: color.withOpacity(0.4), offset: Offset(0, 3)),
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 4 + (2 * adjustedValue),
            color: Colors.white,
            strokeColor: color,
            strokeWidth: 2,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withOpacity(0.15),
      ),
    );
  }

  Widget buildPatientProgress(String patientId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchPatientHealthHistory(patientId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Text("⚠️ No health records available.");
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("📊 Patient Health Progress", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            _buildHealthProgressGraph(snapshot.data!),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _getDoctorData();
    _fadeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_fadeController);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _getDoctorData() async {
    if (_user != null) {
      DocumentSnapshot snapshot = await _firestore.collection('doctors').doc(_user!.uid).get();
      if (snapshot.exists) {
        setState(() {
          doctorData = snapshot.data() as Map<String, dynamic>?;
          _nameController.text = doctorData?['name'] ?? ''; // Pre-fill name
        });
      }
    }
  }

  Future<void> _saveDoctorProfile() async {
    if (_user != null) {
      await _firestore.collection('doctors').doc(_user!.uid).set({
        'name': _nameController.text,
        'specialty': _specialtyController.text,
      });

      setState(() {
        doctorData = {
          'name': _nameController.text,
          'specialty': _specialtyController.text,
        };
      });
    }
  }

  Future<void> _updateDoctorName() async {
    String newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    try {
      await _firestore.collection('doctors').doc(_user!.uid).update({'name': newName});
      setState(() {
        doctorData?['name'] = newName; // Update locally
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Name updated successfully!")));
    } catch (e) {
      print("❌ Error updating name: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Failed to update name.")));
    }
  }


  void _logout() async {
    await _auth.signOut();
    Navigator.pushReplacementNamed(
        context, '/login'); // Redirect to login page after logout
  }

  Future<String> _getPatientName(String patientId) async {
    if (_patientNamesCache.containsKey(patientId)) {
      return _patientNamesCache[patientId]!;
    }

    try {
      DocumentSnapshot patientSnapshot = await _firestore.collection('patients')
          .doc(patientId)
          .get();
      if (patientSnapshot.exists) {
        String name = patientSnapshot['name'] ?? 'Unknown';
        _patientNamesCache[patientId] = name;
        return name;
      }
    } catch (e) {
      print("Error fetching patient name: $e");
    }

    return 'Unknown';
  }


  Future<Map<String, dynamic>?> _getHealthRecords(String patientId) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("health_records")
          .doc(patientId)
          .get();

      if (!doc.exists) {
        print("❌ No health records found.");
        return null;
      }

      var healthData = doc.data() as Map<String, dynamic>; // Ensure it's a map
      var vitalSigns = healthData["vital_signs"] as Map<String,
          dynamic>?; // Extract vital_signs

      print("✅ Health Data: $vitalSigns");
      return vitalSigns; // Return only vital_signs
    } catch (e) {
      print("🚨 Error fetching health records: $e");
      return null;
    }
  }


  Future<void> _showHealthRecordsDialog(String patientId) async {
    Map<String, dynamic>? vitalSigns;
    List<Map<String, dynamic>> healthHistory = [];

    try {
      DocumentSnapshot doc = await _firestore.collection("health_records").doc(patientId).get();
      if (doc.exists) {
        var healthData = doc.data() as Map<String, dynamic>;
        vitalSigns = healthData["vital_signs"] as Map<String, dynamic>?;
      }
      healthHistory = await _fetchPatientHealthHistory(patientId);
    } catch (e) {
      print("🚨 Error fetching health records: $e");
    }

    if (vitalSigns == null && healthHistory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("No health records found.")));
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Patient Health Records"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (vitalSigns != null) ...[
                  Text("🫀 Heart Rate: ${vitalSigns['heart_rate'] ?? 'N/A'} BPM"),
                  Text("💉 Blood Pressure: ${vitalSigns['blood_pressure'] ?? 'N/A'}"),
                  Text("🩸 Sugar Level: ${vitalSigns['sugar_level'] ?? 'N/A'} mg/dL"),
                  SizedBox(height: 10),
                ],
                if (healthHistory.isNotEmpty) ...[
                  Text("📊 Health Progress Graph", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: 300, minHeight: 200),
                      child: SizedBox(
                        width: 300,
                        height: 200,
                        child: _buildHealthProgressGraph(healthHistory),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("Close")),
          ],
        );
      },
    );
  }

  void _startVideoCall(String patientId) async {
    try {
      callId = _firestore.collection('calls').doc().id; // Generate unique call ID
      String roomId = callId!;

      print("📢 Initializing WebRTC for Room ID: $roomId");
      await _webrtcService.initialize(existingRoomId: roomId); // ✅ Initialize WebRTC

      // 🔄 Save Firestore call details FIRST
      await _firestore.collection('calls').doc(callId).set({
        'doctorId': _user!.uid,
        'patientId': patientId,
        'status': 'calling',
        'timestamp': FieldValue.serverTimestamp(),
        'roomId': roomId,
      });

      print("✅ Firestore call document created!");

      // Now create WebRTC SDP Offer
      print("📢 Creating SDP Offer...");
      await _webrtcService.createCall(_user!.uid, patientId); // ✅ Now safe to call

      print("✅ Video Call Started for Room ID: $roomId");

      // ✅ Ensure widget is still mounted before navigating
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoCallScreen(_webrtcService),
        ),
      );
    } catch (e, stackTrace) {
      print("❌ Error starting video call: $e");
      print(stackTrace);
    }
  }

  Future<void> _updateAppointmentStatus(String appointmentId, String patientId,
      String status) async {
    bool confirmAction = await _showConfirmationDialog(status);

    if (confirmAction) {
      Map<String, dynamic> updateData = {'status': status};

      // Add completion timestamp when marking as completed
      if (status == "Completed") {
        updateData['completedAt'] = FieldValue.serverTimestamp();
      }
      await _firestore.collection('appointments').doc(appointmentId).update(
          {'status': status});
      await _firestore
          .collection('patients')
          .doc(patientId)
          .collection('appointments')
          .doc(appointmentId)
          .set({'status': status}, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Appointment marked as $status")));
    }
  }

  Future<bool> _showConfirmationDialog(String status) async {
    return await showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text("Confirm Action"),
            content: Text(
                "Are you sure you want to mark the appointment as $status?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false),
                  child: Text("Cancel")),
              TextButton(onPressed: () => Navigator.pop(context, true),
                  child: Text("Yes")),
            ],
          ),
    ) ??
        false;
  }

  Widget _buildAppointmentRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: _user?.uid)
          .where('status', isEqualTo: 'Pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return Center(child: Text("No pending appointments"));

        final appointments = snapshot.data!.docs;
        return ListView.builder(
          shrinkWrap: true, // ✅ Fix for infinite height issue
          physics: NeverScrollableScrollPhysics(), // ✅ Prevents conflicts with scrolling
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            var appointment = appointments[index].data() as Map<String,
                dynamic>;
            String appointmentId = appointments[index].id;
            String patientId = appointment['patientId'];

            return FutureBuilder<String>(
              future: _getPatientName(patientId),
              builder: (context, patientSnapshot) {
                String patientName = patientSnapshot.data ?? "Fetching...";

                return Card(
                  child: ListTile(
                    title: Text(
                        "📅 ${appointment['date']} at ${appointment['time']}"),
                    subtitle: Text("👤 Patient: $patientName"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ✅ Confirm button
                        IconButton(
                          icon: Icon(Icons.check, color: Colors.green),
                          tooltip: "Confirm Appointment",
                          onPressed: () async {
                            final confirmed = await _showConfirmationDialog("Confirmed");
                            if (confirmed) {
                              await FirebaseFirestore.instance
                                  .collection('appointments')
                                  .doc(appointmentId)
                                  .update({'status': 'Confirmed'});

                              print("✅ Appointment marked as Confirmed");

                              await sendPatientNotification(
                                patientId,
                                "Appointment Confirmed",
                                "Your appointment has been confirmed by the doctor.",
                              );

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Patient has been notified.")),
                              );
                            }
                          },
                        ),

                        // ❌ Reject button
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.red),
                          tooltip: "Reject Appointment",
                          onPressed: () async {
                            final rejected = await _showConfirmationDialog("Rejected");
                            if (rejected) {
                              await FirebaseFirestore.instance
                                  .collection('appointments')
                                  .doc(appointmentId)
                                  .update({'status': 'Rejected'});

                              print("❌ Appointment marked as Rejected");

                              await sendPatientNotification(
                                patientId,
                                "Appointment Rejected",
                                "Your appointment request has been rejected by the doctor.",
                              );

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Patient has been notified.")),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
  Widget _buildAppointmentsInProgress() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: _user?.uid)
          .where('status', isEqualTo: 'Confirmed')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return Center(child: Text("No ongoing appointments"));

        final appointments = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            var appointment = appointments[index].data() as Map<String, dynamic>;
            String appointmentId = appointments[index].id;
            String patientId = appointment['patientId'];

            return FutureBuilder<String>(
              future: _getPatientName(patientId),
              builder: (context, patientSnapshot) {
                String patientName = patientSnapshot.data ?? "Fetching...";

                return Card(
                  child: ListTile(
                    title: Text("📅 ${appointment['date']} at ${appointment['time']}"),
                    subtitle: Text("👤 Patient: $patientName"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.video_call, color: Colors.blue),
                          tooltip: "Start Video Call",
                          onPressed: () => _startVideoCall(patientId),
                        ),
                        IconButton(
                          icon: Icon(Icons.show_chart, color: Colors.purple),
                          tooltip: "View Health Records",
                          onPressed: () => _showHealthRecordsDialog(patientId),
                        ),
                        IconButton(
                          icon: Icon(Icons.check_circle, color: Colors.green),
                          tooltip: "Mark as Completed",
                          onPressed: () => _updateAppointmentStatus(appointmentId, patientId, "Completed"),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }


  Widget _buildPastAppointments() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: _user?.uid)
          .where('status', isEqualTo: 'Completed') // Fetch past confirmed/completed
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return Center(child: Text("No past appointments"));

        final appointments = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            var appointment = appointments[index].data() as Map<String,
                dynamic>;
            String appointmentId = appointments[index].id;
            String patientId = appointment['patientId'];

            return FutureBuilder<String>(
              future: _getPatientName(patientId),
              builder: (context, patientSnapshot) {
                String patientName = patientSnapshot.data ?? "Fetching...";

                return Card(
                  child: ListTile(
                    title: Text(
                        "📅 ${appointment['date']} at ${appointment['time']}"),
                    subtitle: Text("👤 Patient: $patientName"),
                    trailing: IconButton(
                      icon: Icon(Icons.show_chart, color: Colors.purple),
                      tooltip: "View Health Records",
                      onPressed: () => _showHealthRecordsDialog(patientId),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildProfileForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("👨‍⚕️ Enter Your Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(labelText: "Full Name", border: OutlineInputBorder()),
        ),
        SizedBox(height: 10),
        TextField(
          controller: _specialtyController,
          decoration: InputDecoration(labelText: "Specialty", border: OutlineInputBorder()),
        ),
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: _saveDoctorProfile,
          child: Text("Save Profile"),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.cyan,
      appBar: AppBar(
        title: Text('Doctor Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: doctorData == null
            ? _buildProfileForm() // Show profile form if doctorData is null
            : FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Animated Name Field
              Row(
                children: [
                  Expanded(
                    child: AnimatedCrossFade(
                      duration: Duration(milliseconds: 300),
                      crossFadeState: _isEditingName
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: Text(
                        "👨‍⚕️ Name: ${doctorData?['name'] ?? 'Fetching...'}",
                        style: TextStyle(
                            fontSize: 18,
                            color: Colors.black,
                            fontWeight: FontWeight.bold),
                      ),
                      secondChild: TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: "Edit Name",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isEditingName ? Icons.save : Icons.edit,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      if (_isEditingName) {
                        _updateDoctorName(); // Save name
                      }
                      setState(() {
                        _isEditingName = !_isEditingName; // Toggle edit
                      });
                    },
                  ),
                ],
              ),

              Text("📚 Specialty: ${doctorData?['specialty'] ?? "Not Specified"}",
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 20),

              // Write Prescription Button
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => DoctorPatientList()),
                    );
                  },
                  child: Text("Write Prescription"),
                ),
              ),

              SizedBox(height: 20),

              Expanded(
                child: ListView(
                  children: [
                    Text("📅 Pending Appointments",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    _buildAppointmentRequests(),

                    SizedBox(height: 20),

                    Text("⏳ Appointments in Progress",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    _buildAppointmentsInProgress(),

                    SizedBox(height: 20),

                    Text("📜 Past Appointments",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    _buildPastAppointments(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}