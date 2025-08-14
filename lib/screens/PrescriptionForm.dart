import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';

class PrescriptionForm extends StatefulWidget {
  final String patientId;

  const PrescriptionForm({Key? key, required this.patientId}) : super(key: key);

  @override
  _PrescriptionFormState createState() => _PrescriptionFormState();
}

class _PrescriptionFormState extends State<PrescriptionForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _prescriptionController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _timingController = TextEditingController();
  final TextEditingController _feesController = TextEditingController(); // NEW - Fees
  final TextEditingController _upiIdController = TextEditingController(); // NEW - UPI ID

  bool _isLoading = false;

  Future<void> _submitPrescription() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    String doctorId = FirebaseAuth.instance.currentUser!.uid;
    String diagnosis = _diagnosisController.text.trim();
    String prescription = _prescriptionController.text.trim();
    String duration = _durationController.text.trim();
    String timing = _timingController.text.trim();
    double fees = double.tryParse(_feesController.text.trim()) ?? 0.0;
    String upiId = _upiIdController.text.trim();
    String patientId = widget.patientId;

    try {
      // 🔹 Generate Prescription PDF & Encode
      Uint8List pdfData = await generatePrescriptionPDF(
          doctorId, patientId, diagnosis, prescription, duration, timing, fees, upiId);
      String base64PDF = base64Encode(pdfData);

      // 🔹 Save Prescription to Firestore
      await FirebaseFirestore.instance.collection('prescriptions').doc(patientId).set({
        'doctorId': doctorId,
        'patientId': patientId,
        'diagnosis': diagnosis,
        'prescription': prescription,
        'duration': duration,
        'timing': timing,
        'fees': fees,
        'upiId': upiId,
        'pdfBase64': base64PDF,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // ✅ 🔹 Add Medicine Reminder
      await FirebaseFirestore.instance.collection('medicine_reminders').add({
        'patientId': patientId,
        'doctorId': doctorId,
        'medicine': prescription,
        'timing': timing,
        'duration': duration,
        'startDate': Timestamp.now(),
        'status': 'active',
        'timestamp': FieldValue.serverTimestamp(),
      });


      // 🔹 Success Message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Prescription & Reminder saved.')),
      );

      // 🔹 Clear the form fields
      _diagnosisController.clear();
      _prescriptionController.clear();
      _timingController.clear();
      _durationController.clear();
      _feesController.clear();
      _upiIdController.clear();

      // 🔹 Close form after submission
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  Future<Uint8List> generatePrescriptionPDF(String doctorId, String patientId, String diagnosis,
      String prescription, String duration, String timing, double fees, String upiId) async {
    final pdf = pw.Document();

    // Load the custom font
    final font = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Doctor ID: $doctorId", style: pw.TextStyle(fontSize: 18)),
              pw.Text("Patient ID: $patientId", style: pw.TextStyle(fontSize: 18)),
              pw.SizedBox(height: 10),
              pw.Text("Diagnosis:", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text(diagnosis),
              pw.SizedBox(height: 10),
              pw.Text("Prescription:", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text(prescription),
              pw.SizedBox(height: 10),
              pw.Text("Duration (Days): $duration", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text("Timing: $timing", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text("Doctor Fees(in Rupees): $fees", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)), // NEW
              pw.Text("UPI ID for Payment: $upiId", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)), // NEW
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Write Prescription")),
      body: Container(
        color: Colors.cyan, // 🌊 Set background color
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView( // ✅ In case content overflows
            child: Column(
              children: [
                TextFormField(
                  controller: _diagnosisController,
                  decoration: InputDecoration(labelText: "Diagnosis"),
                  validator: (value) => value!.isEmpty ? "Please enter diagnosis" : null,
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: _prescriptionController,
                  decoration: InputDecoration(labelText: "Prescription"),
                  maxLines: 4,
                  validator: (value) => value!.isEmpty ? "Please enter prescription" : null,
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: _durationController,
                  decoration: InputDecoration(labelText: "Duration (Days)"),
                  keyboardType: TextInputType.number,
                  validator: (value) => value!.isEmpty ? "Please enter duration" : null,
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: _timingController,
                  decoration: InputDecoration(labelText: "Timing (e.g., Morning, Night)"),
                  validator: (value) => value!.isEmpty ? "Please enter timing" : null,
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: _feesController,
                  decoration: InputDecoration(labelText: "Doctor Fees (₹)"),
                  keyboardType: TextInputType.number,
                  validator: (value) => value!.isEmpty ? "Please enter consultation fee" : null,
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: _upiIdController,
                  decoration: InputDecoration(labelText: "UPI ID for Payment"),
                  validator: (value) => value!.isEmpty ? "Please enter UPI ID" : null,
                ),
                SizedBox(height: 20),
                _isLoading
                    ? CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _submitPrescription,
                  child: Text("Save Prescription"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
