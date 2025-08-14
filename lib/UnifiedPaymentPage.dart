import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher_string.dart';

class UnifiedPaymentPage extends StatefulWidget {
  @override
  _UnifiedPaymentPageState createState() => _UnifiedPaymentPageState();
}

class _UnifiedPaymentPageState extends State<UnifiedPaymentPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Razorpay _razorpay;

  final _upiIdController = TextEditingController(text: 'yourupi@okaxis');
  final _amountController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    _tabController.dispose();
    super.dispose();
  }

  void openRazorpayCheckout() {
    var options = {
      'key': 'rzp_test_QP4YAHIWFxQErA',
      'amount': 100,
      'name': 'Mobile Health App',
      'description': 'Consultation Fee',
      'prefill': {'contact': '9876543210', 'email': 'patient@example.com'},
      'external': {'wallets': ['paytm']}
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    Fluttertoast.showToast(
        msg: "Payment Successful: ${response.paymentId}",
        backgroundColor: Colors.green);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    Fluttertoast.showToast(
        msg: "Payment Failed: ${response.message}",
        backgroundColor: Colors.red);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    Fluttertoast.showToast(
        msg: "External Wallet: ${response.walletName}",
        backgroundColor: Colors.blue);
  }

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
        'upi://pay?pa=${Uri.encodeComponent(upiId)}&pn=Doctor&tn=Consultation%20Fee&am=${Uri.encodeComponent(amount)}&cu=INR&tr=$transactionRef';

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
      appBar: AppBar(
        title: Text('Choose Payment Method'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Razorpay'),
            Tab(text: 'UPI Payment'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Razorpay Tab with cyan background
          Container(
            color: Colors.cyan,
            child: Center(
              child: ElevatedButton(
                onPressed: openRazorpayCheckout,
                child: Text("Pay with Razorpay"),
              ),
            ),
          ),

          // UPI Payment Tab
          Container(
            color: Colors.cyan,
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
                  child: Text('Pay with UPI'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
