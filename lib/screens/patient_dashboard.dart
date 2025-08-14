import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mha1/screens/health_records_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mha1/services/notification_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mha1/screens/video_call_screen.dart';
import 'package:mha1/screens/webrtc_video_call.dart';
import 'package:mha1/screens/webrtc_helper.dart';
import 'prescription_list.dart';

class PatientDashboard extends StatefulWidget {
  @override
  _PatientDashboardState createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  late WebRTCService _webrtcService;
  String? activeRoomId;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? patientData;
  Map<String, dynamic>? healthData;
  String selectedDoctorId = "";
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _bpController = TextEditingController();
  final TextEditingController _sugarController = TextEditingController();
  final TextEditingController _heartRateController = TextEditingController();
  List<Map<String, dynamic>> doctors = [];
  List<Map<String, dynamic>> filteredDoctors = [];
  List<Map<String, dynamic>> healthHistory = [];


  @override
  void initState() {
    super.initState();
    saveFCMToken();
    _user = _auth.currentUser;
    _getUserData();
    _fetchDoctors();  // ✅ Ensure doctors are fetched at startup
    _fetchUpdatedHealthRecords();
    _fetchHealthHistory();
    _listenForActiveCalls();
    _webrtcService = WebRTCService();

    // 🔥 Initialize Notifications
    NotificationService.initialize();

    // 🔥 Handle Foreground Notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("📩 New Notification: ${message.notification?.title}");
      NotificationService.showNotification(
        message.notification?.title ?? "New Notification",  // Title
        message.notification?.body ?? "You have a new message",  // Body
      );
    });

    // 🔥 Background & Terminated Notifications
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("📩 Notification Clicked: ${message.notification?.title}");
    });
  }

  /// 🔴 Listen for an active call from Firestore
  void _listenForActiveCalls() {
    _firestore
        .collection('calls')
        .where('patientId', isEqualTo: _user?.uid)
        .where('status', isEqualTo: 'calling')
        .snapshots()
        .listen((snapshot) {
      print("📢 Firestore call snapshot: ${snapshot.docs.length}");
      if (snapshot.docs.isNotEmpty) {
        setState(() {
          activeRoomId = snapshot.docs.first['roomId'];
          print("📞 Active Room ID updated: $activeRoomId");
        });
      } else {
        setState(() {
          activeRoomId = null;
        });
      }
    });
  }

  /// 🟢 Join the WebRTC Call
  void _joinCall(String roomId) async {
    if (roomId.isNotEmpty) {
      print("📢 Patient joining call for Room ID: $roomId");

      if (!_webrtcService.isInitialized) {
        await _webrtcService.initialize(existingRoomId: roomId);
      }

      String patientId = FirebaseAuth.instance.currentUser!.uid;
      await _webrtcService.joinCall(roomId, patientId); // Ensure patient joins

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoCallScreen(_webrtcService),
        ),
      );
    } else {
      print("❌ No active call found.");
    }
  }

  Stream<QuerySnapshot> getPatientAppointments() {
    return _firestore
        .collection('appointments')
        .where('patientId', isEqualTo: _user!.uid)
        .snapshots();
  }


  Future<void> _getUserData() async {
    if (_user != null) {
      DocumentSnapshot snapshot =
      await _firestore.collection('patients').doc(_user!.uid).get();
      setState(() {
        patientData = snapshot.data() as Map<String, dynamic>?;
      });
    }
  }

  Future<void> _saveProfileData(String name, String age, String condition) async {
    if (_user != null) {
      await _firestore.collection('patients').doc(_user!.uid).set({
        'name': name,
        'age': age,
        'chronic_condition': condition,
      });

      setState(() {
        patientData = {
          'name': name,
          'age': age,
          'chronic_condition': condition,
        };
      });
    }
  }

  Future<void> _fetchDoctors() async {
    if (_auth.currentUser == null) {
      print("⚠️ User not authenticated.");
      return;
    }

    try {
      QuerySnapshot snapshot = await _firestore.collection('doctors').get();
      print("✅ Doctors fetched: ${snapshot.docs.length}");

      setState(() {
        doctors = snapshot.docs.map((doc) => {
          "uid": doc.id,
          "name": doc["name"],
          "specialty": doc["specialty"] ?? "General",
        }).toList();
        filteredDoctors = doctors;
      });
    } catch (e) {
      print("❌ Error fetching doctors: $e");
    }
  }

  void _filterDoctors(String query) {
    setState(() {
      filteredDoctors = doctors.where((doctor) {
        final nameLower = doctor['name'].toLowerCase();
        final specialtyLower = doctor['specialty'].toLowerCase();
        final searchLower = query.toLowerCase();
        return nameLower.contains(searchLower) || specialtyLower.contains(searchLower);
      }).toList();
    });
  }

  Future<void> sendAppointmentNotification(String doctorId, String title, String body) async {
    DocumentSnapshot doctorDoc = await FirebaseFirestore.instance.collection('users').doc(doctorId).get();

    if (doctorDoc.exists) {
      String? token = doctorDoc['fcmToken'];
      if (token != null) {
        await FirebaseMessaging.instance.sendMessage(
          to: token,
          data: {"title": title, "body": body},
        );
        print("✅ Notification sent to Doctor!");
      } else {
        print("❌ Doctor has no FCM token.");
      }
    } else {
      print("❌ Doctor not found.");
    }
  }

  Future<void> _fetchUpdatedHealthRecords() async {
    if (_user != null) {
      DocumentSnapshot snapshot =
      await _firestore.collection('health_records').doc(_user!.uid).get();

      if (snapshot.exists) {
        setState(() {
          healthData = snapshot.data() as Map<String, dynamic>;
        });
      }
    }
  }

  Future<void> _scheduleAppointment() async {
    print("🔹 Function Called");

    if (_user == null) {
      print("❌ User is NULL");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("User not logged in")),
      );
      return;
    }

    if (selectedDoctorId.isEmpty) {
      print("❌ No doctor selected");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select a doctor")),
      );
      return;
    }

    print("✅ User & Doctor Selected");

    QuerySnapshot appointmentSnapshot = await _firestore
        .collection('appointments')
        .where('doctorId', isEqualTo: selectedDoctorId)
        .where('date', isEqualTo: _dateController.text)
        .where('time', isEqualTo: _timeController.text)
        .where('status', isEqualTo: 'Pending')
        .get();

    if (appointmentSnapshot.docs.isNotEmpty) {
      print("⚠️ Doctor already booked");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Doctor is already booked for this time.")),
      );
      return;
    }

    print("✅ Creating Appointment");

    // 🔹 Call the `bookAppointment` function
    await bookAppointment(selectedDoctorId, _user!.uid);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ Appointment Scheduled Successfully!")),
    );

    _dateController.clear();
    _timeController.clear();
  }

  Future<void> bookAppointment(String doctorId, String patientId) async {
    try {
      // 🔹 Ensure all data is stored in Firestore-compatible format
      Map<String, dynamic> appointmentData = {
        'doctorId': doctorId,
        'patientId': patientId,
        'date': _dateController.text.trim(),  // Ensure it's a string
        'time': _timeController.text.trim(),
        'status': 'Pending',
        'timestamp': FieldValue.serverTimestamp(),  // Correct Firestore timestamp
      };

      DocumentReference appointmentRef =
      await FirebaseFirestore.instance.collection('appointments').add(appointmentData);

      print("✅ Appointment Added to Firestore");

      await FirebaseFirestore.instance
          .collection('doctors')
          .doc(doctorId)
          .collection('appointments')
          .doc(appointmentRef.id)
          .set(appointmentData);

      print("✅ Appointment Linked to Doctor");

      // 🔹 Get Doctor's FCM Token from Firestore
      DocumentSnapshot doctorSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(doctorId)
          .get();

      if (doctorSnapshot.exists && doctorSnapshot.data() != null) {
        String? fcmToken = (doctorSnapshot.data() as Map<String, dynamic>)['fcmToken'];

        if (fcmToken != null && fcmToken.isNotEmpty) {
          // 🔹 Send Notification to Doctor
          await NotificationService.sendNotification(
            fcmToken,
            "New Appointment",
            "You have a new appointment request!",
          );
        } else {
          print("⚠️ Doctor's FCM Token is missing or empty.");
        }
      } else {
        print("⚠️ Doctor data not found.");
      }

      print("✅ Appointment booked & notification sent!");
    } catch (e, stacktrace) {
      print("❌ Error booking appointment: $e");
      print(stacktrace);  // Log stack trace for debugging
    }
  }


  Future<void> _updateHealthRecords() async {
    if (_user != null) {
      if (_bpController.text.isEmpty ||
          _sugarController.text.isEmpty ||
          _heartRateController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("⚠️ Please fill all fields before updating.")),
        );
        return;
      }

      try {
        String userId = _user!.uid;
        Map<String, dynamic> newRecord = {
          'blood_pressure': _bpController.text,
          'sugar_level': _sugarController.text,
          'heart_rate': _heartRateController.text,
          'timestamp': FieldValue.serverTimestamp(),
        };

        // 🔥 Store Latest Record
        await _firestore.collection('health_records').doc(userId).set({
          'vital_signs': newRecord,
          'last_updated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 🔥 Add to History Collection
        await _firestore
            .collection('health_records')
            .doc(userId)
            .collection('history')
            .add(newRecord);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Health Records Updated!")),
        );

        _bpController.clear();
        _sugarController.clear();
        _heartRateController.clear();

        setState(() {
          _fetchUpdatedHealthRecords(); // 🔄 Refresh Data
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error: ${e.toString()}")),
        );
      }
    }
  }

  Future<void> _fetchHealthHistory() async {
    if (_user != null) {
      try {
        QuerySnapshot snapshot = await _firestore
            .collection('health_records')
            .doc(_user!.uid)
            .collection('history')
            .orderBy('timestamp', descending: true)
            .get();

        setState(() {
          healthHistory = snapshot.docs.map((doc) {
            return {
              "bp": doc["blood_pressure"],
              "sugar": doc["sugar_level"],
              "heart_rate": doc["heart_rate"],
              "date": (doc["timestamp"] as Timestamp).toDate().toString().split(' ')[0],
            };
          }).toList();
        });

      } catch (e) {
        print("❌ Error fetching health history: $e");
      }
    }
  }


  Future<void> _updatePatientProfile(String name, int age, String chronicCondition) async {
    if (_user != null) {
      await _firestore.collection('patients').doc(_user!.uid).update({
        'name': name,
        'age': age,
        'chronic_condition': chronicCondition,
      });

      setState(() {
        patientData?['name'] = name;
        patientData?['age'] = age;
        patientData?['chronic_condition'] = chronicCondition;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Profile Updated Successfully!")),
      );
    }
  }

  void _showEditProfileDialog() {
    // Text controllers to hold current values
    TextEditingController _nameController = TextEditingController(text: patientData?['name']);
    TextEditingController _ageController = TextEditingController(text: patientData?['age'].toString());
    TextEditingController _chronicConditionController = TextEditingController(text: patientData?['chronic_condition']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit Profile"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nameController, decoration: InputDecoration(labelText: "Name")),
            TextField(controller: _ageController, decoration: InputDecoration(labelText: "Age"), keyboardType: TextInputType.number),
            TextField(controller: _chronicConditionController, decoration: InputDecoration(labelText: "Chronic Condition")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
          TextButton(
            onPressed: () {
              _updatePatientProfile(
                _nameController.text,
                int.tryParse(_ageController.text) ?? 0,
                _chronicConditionController.text,
              );
              Navigator.pop(context); // Close dialog after saving
            },
            child: Text("Save"),
          ),
        ],
      ),
    );
  }


  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  void saveFCMToken() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    String? token = await messaging.getToken();

    if (token != null) {
      String userId = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'fcmToken': token,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.cyan,
      appBar: AppBar(
        title: Text('Patient Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: patientData == null ? _buildProfileForm() : _buildDashboard(),
    );
  }

  Widget _buildProfileForm() {
    TextEditingController nameController = TextEditingController();
    TextEditingController ageController = TextEditingController();
    TextEditingController conditionController = TextEditingController();

    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: nameController,
            decoration: InputDecoration(labelText: "Name"),
          ),
          TextField(
            controller: ageController,
            decoration: InputDecoration(labelText: "Age"),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: conditionController,
            decoration: InputDecoration(labelText: "Chronic Condition"),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              _saveProfileData(nameController.text, ageController.text, conditionController.text);
            },
            child: Text("Save Profile"),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: ListView(
        children: [
          Text("👤 Name: ${patientData!['name']}", style: TextStyle(fontSize: 18)),
          Text("🎂 Age: ${patientData!['age']}", style: TextStyle(fontSize: 18)),
          Text("💊 Chronic Condition: ${patientData!['chronic_condition']}", style: TextStyle(fontSize: 18)),
          SizedBox(height: 20),

          // 🔥 Add "Join Call" Button if an active call exists
          if (activeRoomId != null)
            ElevatedButton(
              onPressed: () => _joinCall(activeRoomId!),
              child: Text("📞 Join Video Call"),
            ),

          SizedBox(height: 20),

          Text("📅 Schedule an Appointment", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          _buildAppointmentForm(),
          SizedBox(height: 20),

          Text("📂 Latest Health Records", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          _buildUpdatedHealthRecordsView(),
          SizedBox(height: 20),

          Text("📝 Update Health Records", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          _buildUpdateHealthRecordsForm(),

          SizedBox(height: 20),

          Text("📋 My Appointments", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          _buildAppointmentsList(), // Add the appointments list here

          SizedBox(height: 20),

          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PrescriptionList()),
              );
            },
            child: Text("📄 View Prescriptions"),
          ),

          SizedBox(height: 20),

          ElevatedButton(
            onPressed: () => _showEditProfileDialog(),
            child: Text("✏️ Edit Profile"),
          ),

        ],
      ),
    );
  }

  Widget _buildAppointmentForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: "🔍 Search Doctor by Name/Specialty",
            suffixIcon: Icon(Icons.search),
          ),
          onChanged: (query) => _filterDoctors(query),
        ),
        SizedBox(height: 10),

        FutureBuilder<QuerySnapshot>(
          future: _firestore.collection('doctors').get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Text("⚠️ No doctors available.");
            }

            doctors = snapshot.data!.docs.map((doc) {
              return {
                "uid": doc.id,
                "name": doc["name"] ?? "Unknown",
                "specialty": doc["specialty"] ?? "General",
              };
            }).toList();

            return DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: "Select a Doctor"),
              value: selectedDoctorId.isNotEmpty ? selectedDoctorId : null,
              items: doctors.map((doctor) {
                return DropdownMenuItem<String>(
                  value: doctor["uid"],
                  child: Text("${doctor['name']} - ${doctor['specialty']}"),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedDoctorId = value!;
                });
              },
            );
          },
        ),

        SizedBox(height: 10),

        TextField(
          controller: _dateController,
          decoration: InputDecoration(
            labelText: "📅 Select Date",
            suffixIcon: Icon(Icons.calendar_today),
          ),
          readOnly: true,
          onTap: () async {
            DateTime? pickedDate = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime(2100),
            );
            if (pickedDate != null) {
              setState(() {
                _dateController.text = "${pickedDate.toLocal()}".split(' ')[0];
              });
            }
          },
        ),

        TextField(
          controller: _timeController,
          decoration: InputDecoration(
            labelText: "⏰ Select Time",
            suffixIcon: Icon(Icons.access_time),
          ),
          readOnly: true,
          onTap: () async {
            TimeOfDay? pickedTime = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
            );
            if (pickedTime != null) {
              setState(() {
                _timeController.text = pickedTime.format(context);
              });
            }
          },
        ),

        ElevatedButton(
          onPressed: () async {
            await _scheduleAppointment();
          },
          child: Text("🗓️ Request Consultation"),
        ),

        SizedBox(height: 10),

        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: ()  {
             _cancelAppointment();
          },
          child: Text("❌ Cancel Appointment", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
  void _cancelAppointment() async {
    if (selectedDoctorId.isEmpty || _dateController.text.isEmpty || _timeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Please select a doctor and provide a valid date/time.")),
      );
      return;
    }

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('appointments')
          .where('patientId', isEqualTo: _user!.uid)
          .where('doctorId', isEqualTo: selectedDoctorId)
          .where('date', isEqualTo: _dateController.text)
          .where('time', isEqualTo: _timeController.text)
          .where('status', isEqualTo: 'Pending')  // Ensure only pending appointments are canceled
          .get();

      if (snapshot.docs.isNotEmpty) {
        // Delete from 'appointments' collection
        await _firestore.collection('appointments').doc(snapshot.docs.first.id).delete();

        // Also remove from the doctor's subcollection
        await _firestore
            .collection('doctors')
            .doc(selectedDoctorId)
            .collection('appointments')
            .doc(snapshot.docs.first.id)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Appointment canceled successfully.")),
        );

        setState(() {
          selectedDoctorId = "";
          _dateController.clear();
          _timeController.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ No pending appointment found to cancel.")),
        );
      }
    } catch (e) {
      print("❌ Error canceling appointment: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error canceling appointment. Please try again.")),
      );
    }
  }


  Widget _buildUpdatedHealthRecordsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        healthData == null
            ? Text("No health records available.")
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("🩸 Blood Pressure: ${healthData!['vital_signs']['blood_pressure']}"),
            Text("🍬 Sugar Level: ${healthData!['vital_signs']['sugar_level']}"),
            Text("❤️ Heart Rate: ${healthData!['vital_signs']['heart_rate']}"),
          ],
        ),
        SizedBox(height: 20),
        Text("📜 Health Records History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        _buildHealthHistoryList(),
      ],
    );
  }


  Widget _buildUpdateHealthRecordsForm() {
    return Column(
      children: [
        TextField(controller: _bpController, decoration: InputDecoration(labelText: "🩸 Blood Pressure")),
        TextField(controller: _sugarController, decoration: InputDecoration(labelText: "🍬 Sugar Level")),
        TextField(controller: _heartRateController, decoration: InputDecoration(labelText: "❤️ Heart Rate")),
        SizedBox(height: 10),
        ElevatedButton(onPressed: _updateHealthRecords, child: Text("💾 Update Health Records")),
      ],
    );
  }

  Widget _buildHealthHistoryList() {
    if (healthHistory.isEmpty) {
      return Text("📌 No health history available.");
    }

    return Column(
      children: healthHistory.map((record) {
        return Card(
          child: ListTile(
            title: Text("📅 Date: ${record['date']}"),
            subtitle: Text(
              "🩸 BP: ${record['bp']}\n"
                  "🍬 Sugar: ${record['sugar']}\n"
                  "❤️ Heart Rate: ${record['heart_rate']}",
            ),
          ),
        );
      }).toList(),
    );
  }


  Widget _buildAppointmentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: getPatientAppointments(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text("📌 No Appointments Found.");
        }

        return Column(
          children: snapshot.data!.docs.map((doc) {
            Map<String, dynamic> appointment = doc.data() as Map<String, dynamic>;
            String doctorId = appointment['doctorId'] ?? "";
            String meetingLink = appointment['meetingLink'] ?? "";

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(doctorId).get(),
              builder: (context, doctorSnapshot) {
                String doctorName = "Unknown Doctor"; // Default name
                if (doctorSnapshot.hasData && doctorSnapshot.data!.exists) {
                  doctorName = doctorSnapshot.data!.get('name') ?? "Unknown Doctor";
                }

                return Card(
                  child: ListTile(
                    title: Text("Doctor Name: $doctorName"), // ✅ Show Doctor's Name
                    subtitle: Text(
                      "📅 Date: ${appointment['date']}\n⏰ Time: ${appointment['time']}\n📌 Status: ${appointment['status']}",
                    ),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }
}

