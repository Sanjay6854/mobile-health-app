import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminReportsAnalyticsScreen extends StatefulWidget {
  const AdminReportsAnalyticsScreen({super.key});

  @override
  State<AdminReportsAnalyticsScreen> createState() => _AdminReportsAnalyticsScreenState();
}

class _AdminReportsAnalyticsScreenState extends State<AdminReportsAnalyticsScreen> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int totalDoctors = 0;
  int totalPatients = 0;
  int totalAppointments = 0;
  int pendingAppointments = 0;
  int confirmedAppointments = 0;
  int completedAppointments = 0;

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // ✅ Fetch Data from Firestore
  Future<void> _fetchData() async {
    try {
      var usersSnapshot = await _firestore.collection('users').get();
      var appointmentsSnapshot = await _firestore.collection('appointments').get();

      int doctors = 0;
      int patients = 0;
      int pending = 0, confirmed = 0, completed = 0;

      for (var doc in usersSnapshot.docs) {
        String role = doc['role'] ?? '';
        if (role == 'doctor') {
          doctors++;
        } else if (role == 'patient') {
          patients++;
        }
      }

      for (var appointment in appointmentsSnapshot.docs) {
        String status = appointment['status'] ?? '';
        if (status == 'Pending') {
          pending++;
        } else if (status == 'Confirmed') {
          confirmed++;
        } else if (status == 'Completed') {
          completed++;
        }
      }

      setState(() {
        totalDoctors = doctors;
        totalPatients = patients;
        totalAppointments = appointmentsSnapshot.size;
        pendingAppointments = pending;
        confirmedAppointments = confirmed;
        completedAppointments = completed;
      });
    } catch (e) {
      print("Error fetching reports: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchData();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.cyan,
      appBar: AppBar(title: const Text("Reports & Analytics")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Users Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Flexible(child: _statCard("Total Doctors", totalDoctors, Colors.blue)),
                      Flexible(child: _statCard("Total Patients", totalPatients, Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const Text("Appointments Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _statCard("Total Appointments", totalAppointments, Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const Text("Appointments Status", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _buildPieChart(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ Widget for Statistic Cards
  Widget _statCard(String title, int value, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        width: 160,
        height: 90,
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value.toString(),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Pie Chart for Appointment Status
  Widget _buildPieChart() {
    return SizedBox(
      height: 250,
      child: PieChart(
        PieChartData(
          startDegreeOffset: 180, // Optional rotation
          sections: [
            PieChartSectionData(
              value: pendingAppointments.toDouble(),
              title: "Pending",
              color: Colors.orange,
              radius: 60,
            ),
            PieChartSectionData(
              value: confirmedAppointments.toDouble(),
              title: "Confirmed",
              color: Colors.blue,
              radius: 60,
            ),
            PieChartSectionData(
              value: completedAppointments.toDouble(),
              title: "Completed",
              color: Colors.green,
              radius: 60,
            ),
          ],
          sectionsSpace: 4,
          centerSpaceRadius: 40,
        ),
      ),
    );
  }
}
