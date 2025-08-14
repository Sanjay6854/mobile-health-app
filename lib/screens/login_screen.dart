import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';
import 'patient_dashboard.dart';
import 'doctor_dashboard.dart';
import 'admin_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isHovered = false;

  bool _validateInputs() {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email and Password are required.")),
      );
      return false;
    }
    return true;
  }

  Future<void> _signIn() async {
    if (!_validateInputs()) return;
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    String? error = await authProvider.signIn(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      _navigateToDashboard(authProvider);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    String? error = await authProvider.signInWithGoogle();
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      _navigateToDashboard(authProvider);
    }
  }

  void _navigateToDashboard(AuthProvider authProvider) async {
    if (authProvider.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User not found.")));
      return;
    }

    String? role = await authProvider.getUserRole(authProvider.user!.uid);
    if (!mounted) return;

    if (role == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error fetching role.")));
      return;
    }

    if (role.toLowerCase() == "patient") {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PatientDashboard()));
    } else if (role.toLowerCase() == "doctor") {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DoctorDashboard()));
    } else if (role.toLowerCase() == "admin") {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AdminDashboard()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid role.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Single Color Background
          AnimatedContainer(
            duration: Duration(seconds: 2),
            decoration: BoxDecoration(
              color: Colors.cyan, // Solid cyan background
            ),
          ),

          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo with Circular Glow Effect
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: Image.asset('assets/logo.jpg', height: 120),
                      ),
                    ),

                    // Glassmorphic Card
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1), // Transparent effect
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.3)), // Light border
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(25.0),
                            child: Column(
                              children: [
                                const Text(
                                  "Welcome!",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Email Field
                                TextField(
                                  controller: _emailController,
                                  style: TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: "Email",
                                    labelStyle: TextStyle(color: Colors.white),
                                    prefixIcon: Icon(Icons.email, color: Colors.white),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.1),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                const SizedBox(height: 15),

                                // Password Field
                                TextField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  style: TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: "Password",
                                    labelStyle: TextStyle(color: Colors.white),
                                    prefixIcon: Icon(Icons.lock, color: Colors.white),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.1),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Buttons
                                _isLoading
                                    ? CircularProgressIndicator()
                                    : Column(
                                  children: [
                                    ElevatedButton(
                                      onPressed: _signIn,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                                      ),
                                      child: Text("Login", style: TextStyle(fontSize: 18, color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(height: 10),

                                    ElevatedButton.icon(
                                      onPressed: _signInWithGoogle,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white.withOpacity(0.2),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          side: BorderSide(color: Colors.white.withOpacity(0.5)),
                                        ),
                                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      ),
                                      icon: Image.asset("assets/google_logo.png", height: 20),
                                      label: Text("Sign in with Google", style: TextStyle(fontSize: 16, color: Colors.white)),
                                    ),
                                    const SizedBox(height: 10),

                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(context, MaterialPageRoute(builder: (context) => RegisterScreen()));
                                      },
                                      child: MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        onEnter: (event) => setState(() => _isHovered = true),
                                        onExit: (event) => setState(() => _isHovered = false),
                                        child: AnimatedDefaultTextStyle(
                                          duration: Duration(milliseconds: 300),
                                          style: TextStyle(
                                            color: _isHovered ? Colors.white70 : Colors.white, // Hover effect
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            decoration: _isHovered ? TextDecoration.underline : TextDecoration.none,
                                          ),
                                          child: Text(
                                            "Don't have an account? Register here",
                                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}