import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<List<Map<String, dynamic>>> fetchPrescriptions() async {
  String patientId = FirebaseAuth.instance.currentUser!.uid;

  QuerySnapshot querySnapshot = await FirebaseFirestore.instance
      .collection('prescriptions')
      .where('patientId', isEqualTo: patientId) // ✅ Filter by patient ID
      .get();

  return querySnapshot.docs.map((doc) {
    var data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;  // ✅ Store the document ID
    return data;
  }).toList();
}
