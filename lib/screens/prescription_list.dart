import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';  // For UPI deep linking
import '../services/prescription_service.dart';
import '../utils/download_helper.dart';
import 'dart:math';
import '../upi_payment_page.dart';
import '../payment_page.dart';
import '../UnifiedPaymentPage.dart';

class PrescriptionList extends StatefulWidget {
  @override
  _PrescriptionListState createState() => _PrescriptionListState();
}

class _PrescriptionListState extends State<PrescriptionList> {
  late Future<List<Map<String, dynamic>>> prescriptions;
  TextEditingController amountController = TextEditingController();
  TextEditingController upiController = TextEditingController();
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    prescriptions = fetchPrescriptions();

    // Start fade-in after small delay
    Future.delayed(Duration(milliseconds: 200), () {
      setState(() {
        _opacity = 1.0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Prescriptions')),
      body: Container(
        color: Colors.cyan,
        child: AnimatedOpacity(
          duration: Duration(milliseconds: 800),
          curve: Curves.easeIn,
          opacity: _opacity,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: prescriptions,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(child: Text("No prescriptions found."));
              }

              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  var prescription = snapshot.data![index];

                  return Card(
                    child: ListTile(
                      title: Text("Diagnosis: ${prescription['diagnosis']}"),
                      subtitle: Text("Duration: ${prescription['duration']} days"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.download),
                            onPressed: () {
                              downloadPrescription(prescription['pdfBase64']);
                            },
                          ),
                          SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => UnifiedPaymentPage()),
                              );
                            },
                            child: Text('Pay Now'),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
