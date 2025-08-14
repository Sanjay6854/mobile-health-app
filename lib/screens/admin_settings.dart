import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? adminUser;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  late AnimationController _fadeController;
  late AnimationController _tileAnimationController;
  late Animation<Offset> _slideAnimation;

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();

  bool _isButtonPressed = false;

  @override
  void initState() {
    super.initState();
    adminUser = _auth.currentUser;
    _nameController.text = adminUser?.displayName ?? "";
    _emailController.text = adminUser?.email ?? "";

    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeController.forward();

    _tileAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _slideAnimation = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _tileAnimationController, curve: Curves.easeOut));

    _tileAnimationController.forward();

    _nameFocus.addListener(() => setState(() {}));
    _emailFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _tileAnimationController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  void _updateProfile() async {
    if (adminUser != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(adminUser!.uid).update({
          'name': _nameController.text.trim(),
        });
        _showSnackbar("✅ Profile updated successfully!");
      } catch (e) {
        _showSnackbar("Error updating profile: ${e.toString()}");
      }
    }
  }

  void _updateEmail() async {
    try {
      await adminUser?.updateEmail(_emailController.text);
      _showSnackbar("✅ Email updated successfully!");
    } catch (e) {
      _showSnackbar("Error: ${e.toString()}");
    }
  }

  void _changePassword() async {
    if (adminUser != null) {
      try {
        await _auth.sendPasswordResetEmail(email: adminUser!.email!);
        _showSnackbar("✅ Password reset email sent!");
      } catch (e) {
        _showSnackbar("Error: ${e.toString()}");
      }
    }
  }

  void _logout() async {
    await _auth.signOut();
    Navigator.pushReplacementNamed(context, "/login");
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeController,
      child: Scaffold(
        backgroundColor: Colors.cyan,
        appBar: AppBar(title: const Text("Settings")),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Admin Profile", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                // Animated TextField for Name
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _nameFocus.hasFocus ? Colors.blue : Colors.grey,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: TextField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    decoration: const InputDecoration(
                      labelText: "Admin Name",
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Animated TextField for Email
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _emailFocus.hasFocus ? Colors.blue : Colors.grey,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: TextField(
                    controller: _emailController,
                    focusNode: _emailFocus,
                    decoration: const InputDecoration(
                      labelText: "Admin Email",
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTapDown: (_) => setState(() => _isButtonPressed = true),
                      onTapUp: (_) => setState(() => _isButtonPressed = false),
                      onTapCancel: () => setState(() => _isButtonPressed = false),
                      onTap: _updateProfile,
                      child: AnimatedScale(
                        scale: _isButtonPressed ? 0.95 : 1.0,
                        duration: const Duration(milliseconds: 100),
                        child: ElevatedButton(
                          onPressed: _updateProfile,
                          child: const Text("Save Name"),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _updateEmail,
                      child: const Text("Save Email"),
                    ),
                  ],
                ),

                const Divider(height: 40),

                const Text("Account Settings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

                const SizedBox(height: 10),

                // Animated ListTile
                SlideTransition(
                  position: _slideAnimation,
                  child: ListTile(
                    leading: const Icon(Icons.lock, color: Colors.orange),
                    title: const Text("Change Password"),
                    onTap: _changePassword,
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),

                const SizedBox(height: 10),

                SlideTransition(
                  position: _slideAnimation,
                  child: ListTile(
                    leading: const Icon(Icons.exit_to_app, color: Colors.red),
                    title: const Text("Logout"),
                    onTap: _logout,
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
