import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:mha1/screens/login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => RegisterScreenState();
}

class RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedRole = "patient"; // Default role
  bool _isLoading = false;
  bool _isHovered = false;

  void _signUp() async {
    setState(() => _isLoading = true);

    String? error = await context.read<AuthProvider>().signUp(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _selectedRole,
      _nameController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)));
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
                    SizedBox(height: 20),

                    // Registration Card with Glassmorphism Effect
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTextField("Full Name", Icons.person, _nameController),
                          SizedBox(height: 12),
                          _buildTextField("Email", Icons.email, _emailController),
                          SizedBox(height: 12),
                          _buildTextField("Password", Icons.lock, _passwordController, isPassword: true),
                          SizedBox(height: 12),

                          // Role Selection
                          DropdownButtonFormField<String>(
                            value: _selectedRole,
                            decoration: InputDecoration(
                              labelText: "Select Role",
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.2),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            dropdownColor: Colors.cyan.shade200,
                            items: ["patient", "doctor", "admin"].map((role) {
                              return DropdownMenuItem(
                                value: role,
                                child: Text(role.toUpperCase(), style: TextStyle(color: Colors.white)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedRole = value!;
                              });
                            },
                            style: TextStyle(color: Colors.white),
                          ),
                          SizedBox(height: 20),

                          // Register Button
                          _isLoading
                              ? Center(child: CircularProgressIndicator(color: Colors.white))
                              : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.9),
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              elevation: 5,
                            ),
                            onPressed: _signUp,
                            child: Text(
                              "Register",
                              style: TextStyle(fontSize: 18, color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),

                    // Login Navigation with Hover Effect
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => LoginScreen()));
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
                            "Already have an account? Login here",
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
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

  // Custom method for text fields
  Widget _buildTextField(String label, IconData icon, TextEditingController controller, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.white),
        filled: true,
        fillColor: Colors.white.withOpacity(0.2),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      style: TextStyle(color: Colors.white),
      obscureText: isPassword,
    );
  }
}
