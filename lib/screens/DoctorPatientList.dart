import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'PrescriptionForm.dart';

class DoctorPatientList extends StatefulWidget {
  @override
  _DoctorPatientListState createState() => _DoctorPatientListState();
}

class _DoctorPatientListState extends State<DoctorPatientList>
    with SingleTickerProviderStateMixin {
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    // Trigger the fade-in effect after the widget is built
    Future.delayed(Duration(milliseconds: 200), () {
      setState(() {
        _opacity = 1.0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Select Patient")),
      body: Container(
        color: Colors.cyan,
        child: AnimatedOpacity(
          opacity: _opacity,
          duration: Duration(milliseconds: 800),
          curve: Curves.easeIn,
          child: StreamBuilder(
            stream:
            FirebaseFirestore.instance.collection('patients').snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (!snapshot.hasData)
                return Center(child: CircularProgressIndicator());

              var patients = snapshot.data!.docs;

              return ListView.builder(
                itemCount: patients.length,
                itemBuilder: (context, index) {
                  var patient = patients[index];
                  return Card(
                    child: ListTile(
                      title: Text(patient['name']),
                      subtitle: Text("ID: ${patient.id}"),
                      trailing: Icon(Icons.arrow_forward),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                PrescriptionForm(patientId: patient.id),
                          ),
                        );
                      },
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
