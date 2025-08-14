import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminManageUsersScreen extends StatefulWidget {
  const AdminManageUsersScreen({super.key});

  @override
  State<AdminManageUsersScreen> createState() => _AdminManageUsersScreenState();
}

class _AdminManageUsersScreenState extends State<AdminManageUsersScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(duration: const Duration(milliseconds: 600), vsync: this);

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ✅ Fetch Users (Excluding Admin)
  Stream<QuerySnapshot> _getUsersStream() {
    return _firestore
        .collection('users')
        .where('role', whereIn: ['doctor', 'patient'])
        .snapshots();
  }

  // ✅ Toggle Active/Inactive Status
  void _toggleUserStatus(String userId, bool currentStatus) async {
    await _firestore.collection('users').doc(userId).update({
      "isActive": !currentStatus,
    });
  }

  // ✅ Delete User Function
  void _deleteUser(String userId) async {
    await _firestore.collection('users').doc(userId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("User Deleted Successfully!")),
    );
  }

  // ✅ Show Add/Edit User Dialog
  void _showUserDialog({String? userId, String? name, String? role, bool? isActive}) {
    final TextEditingController nameController = TextEditingController(text: name ?? "");
    final List<String> roles = ["Doctor", "Patient"];
    String selectedRole = roles.contains(role) ? role! : "Patient";

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(userId == null ? "Add New User" : "Edit User"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedRole,
                items: roles.map((role) {
                  return DropdownMenuItem(value: role, child: Text(role));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedRole = value;
                    });
                  }
                },
                decoration: const InputDecoration(labelText: "Role"),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  if (userId == null) {
                    await _firestore.collection('users').add({
                      "name": nameController.text,
                      "role": selectedRole,
                      "isActive": true,
                    });
                  } else {
                    await _firestore.collection('users').doc(userId).update({
                      "name": nameController.text,
                      "role": selectedRole,
                    });
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.cyan,
      appBar: AppBar(title: const Text("Manage Users")),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: StreamBuilder<QuerySnapshot>(
            stream: _getUsersStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text("Error fetching users"));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No Users Found"));
              }

              final users = snapshot.data!.docs;

              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  var user = users[index];
                  var userId = user.id;
                  var userData = user.data() as Map<String, dynamic>;

                  bool isActive = userData['isActive'] ?? true;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: Icon(userData['role'] == 'Doctor'
                            ? Icons.medical_services
                            : Icons.person),
                        title: Text(userData['name'] ?? "No Name"),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(userData['role'] ?? "Unknown Role"),
                            Text(
                              isActive ? "🟢 Active" : "🔴 Inactive",
                              style: TextStyle(
                                  color: isActive ? Colors.green : Colors.red),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: isActive,
                              onChanged: (value) =>
                                  _toggleUserStatus(userId, isActive),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showUserDialog(
                                userId: userId,
                                name: userData['name'] ?? "",
                                role: userData['role'] ?? "Patient",
                                isActive: isActive,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteUser(userId),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _fadeAnimation,
        child: FloatingActionButton(
          onPressed: () => _showUserDialog(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
