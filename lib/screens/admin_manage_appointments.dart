import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminManageAppointmentsScreen extends StatefulWidget {
  const AdminManageAppointmentsScreen({super.key});

  @override
  State<AdminManageAppointmentsScreen> createState() => _AdminManageAppointmentsScreenState();
}

class _AdminManageAppointmentsScreenState extends State<AdminManageAppointmentsScreen> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<AnimationController> _controllers = [];

  // ✅ Fetch Appointments from Firestore
  Stream<QuerySnapshot> _getAppointmentsStream() {
    return _firestore.collection('appointments').snapshots();
  }

  // ✅ Show Patient Health Data with animated dialog
  void _showHealthData(String patientId) async {
    var patientDoc = await _firestore.collection('health_records').doc(patientId).get();

    if (patientDoc.exists) {
      var healthData = patientDoc.data();
      var vitalSigns = healthData?['vital_signs'];

      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Health Data',
        pageBuilder: (context, animation, secondaryAnimation) {
          return ScaleTransition(
            scale: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
            child: AlertDialog(
              title: const Text("Health Data"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Blood Pressure: ${vitalSigns?['blood_pressure'] ?? 'N/A'}"),
                  Text("Sugar Level: ${vitalSigns?['sugar_level'] ?? 'N/A'}"),
                  Text("Heart Rate: ${vitalSigns?['heart_rate'] ?? 'N/A'}"),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))
              ],
            ),
          );
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No health data found!")),
      );
    }
  }

  // ✅ Confirm & Delete Appointment
  void _confirmDeleteAppointment(String appointmentId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Appointment"),
          content: const Text("Are you sure you want to delete this appointment?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteAppointment(appointmentId);
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // ✅ Delete Appointment from Firestore
  Future<void> _deleteAppointment(String appointmentId) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Appointment deleted successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting appointment: $e")),
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.cyan,
      appBar: AppBar(title: const Text("Manage Appointments")),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getAppointmentsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Error fetching appointments"));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No Appointments Found"));

          final appointments = snapshot.data!.docs;

          return ListView.builder(
            itemCount: appointments.length,
            itemBuilder: (context, index) {
              var appointment = appointments[index];
              var appointmentData = appointment.data() as Map<String, dynamic>;
              String appointmentId = appointment.id;
              String patientId = appointmentData['patientId'] ?? "";
              String doctorId = appointmentData['doctorId'] ?? "";

              // Setup animation controller for each card
              final controller = AnimationController(
                vsync: this,
                duration: const Duration(milliseconds: 500),
              );
              _controllers.add(controller);
              final animation = CurvedAnimation(parent: controller, curve: Curves.easeInOut);
              controller.forward();

              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('users').doc(patientId).get(),
                builder: (context, patientSnapshot) {
                  if (!patientSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                  String patientName = patientSnapshot.data?.exists == true ? patientSnapshot.data!['name'] : "Unknown Patient";

                  return FutureBuilder<DocumentSnapshot>(
                    future: _firestore.collection('users').doc(doctorId).get(),
                    builder: (context, doctorSnapshot) {
                      if (!doctorSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                      String doctorName = doctorSnapshot.data?.exists == true ? doctorSnapshot.data!['name'] : "Unknown Doctor";

                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(1, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: Card(
                            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            elevation: 3,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today, color: Colors.blue, size: 40),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text("Patient: $patientName",
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            Text("Doctor: $doctorName", style: const TextStyle(fontSize: 14)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        children: [
                                          Text(
                                            appointmentData['status'],
                                            style: TextStyle(
                                              color: _getStatusColor(appointmentData['status']),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          _AnimatedIconButton(
                                            icon: Icons.health_and_safety,
                                            color: Colors.green,
                                            onPressed: () => _showHealthData(patientId),
                                          ),
                                          _AnimatedIconButton(
                                            icon: Icons.delete,
                                            color: Colors.red,
                                            onPressed: () => _confirmDeleteAppointment(appointmentId),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.event, color: Colors.red, size: 20),
                                      const SizedBox(width: 5),
                                      Text("Date: ${appointmentData['date']}", style: const TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time, color: Colors.red, size: 20),
                                      const SizedBox(width: 5),
                                      Text("Time: ${appointmentData['time']}", style: const TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Confirmed':
        return Colors.blue;
      case 'Completed':
        return Colors.green;
      default:
        return Colors.black;
    }
  }
}

// ✅ Animated Icon Button Widget
class _AnimatedIconButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _AnimatedIconButton({required this.icon, required this.color, required this.onPressed});

  @override
  State<_AnimatedIconButton> createState() => __AnimatedIconButtonState();
}

class __AnimatedIconButtonState extends State<_AnimatedIconButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150), lowerBound: 0.8, upperBound: 1.0);
    _controller.value = 1.0;
  }

  void _onTap() async {
    await _controller.reverse();
    await _controller.forward();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: ScaleTransition(
        scale: _controller,
        child: Icon(widget.icon, color: widget.color),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
