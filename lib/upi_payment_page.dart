import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

class UpiPaymentPage extends StatefulWidget {
  @override
  _UpiPaymentPageState createState() => _UpiPaymentPageState();
}

class _UpiPaymentPageState extends State<UpiPaymentPage> {
  final _upiIdController = TextEditingController(text: 'yourupi@okaxis'); // <- replace with your real UPI
  final _amountController = TextEditingController(text: '1');

  Future<void> _launchUpiPayment() async {
    final upiId = _upiIdController.text.trim();
    final amount = _amountController.text.trim();

    if (upiId.isEmpty || amount.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter both UPI ID and Amount')),
      );
      return;
    }

    final transactionRef = DateTime.now().millisecondsSinceEpoch.toString();

    final url =
        'upi://pay?pa=${Uri.encodeComponent(upiId)}'
        '&pn=Doctor'
        '&tn=Consultation%20Fee'
        '&am=${Uri.encodeComponent(amount)}'
        '&cu=INR'
        '&tr=$transactionRef';

    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No UPI app found on device')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('UPI Payment')),
      body: Container(
        color: Colors.cyan, // 🌊 Cyan background
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _upiIdController,
              decoration: InputDecoration(labelText: 'Enter UPI ID'),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Enter Amount (INR)'),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: _launchUpiPayment,
              child: Text('Pay Now'),
            ),
          ],
        ),
      ),
    );
  }
}
