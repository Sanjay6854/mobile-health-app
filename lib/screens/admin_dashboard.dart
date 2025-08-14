import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_manage_users.dart';
import 'admin_manage_appointments.dart';
import 'admin_reports_analytics.dart';
import 'admin_settings.dart';
import 'package:flutter/services.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.decelerate),
    );

    // 🔥 Glow Animation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 4.0, end: 15.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _logout() async {
    await _auth.signOut();
    Navigator.pushReplacementNamed(context, "/login");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.cyan,
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: "Logout",
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _dashboardCard(Icons.group, "Manage Users", () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => AdminManageUsersScreen()));
                  }, 0),
                  _dashboardCard(Icons.calendar_today, "Manage Appointments", () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => AdminManageAppointmentsScreen()));
                  }, 1),
                  _dashboardCard(Icons.analytics, "Reports & Analytics", () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => AdminReportsAnalyticsScreen()));
                  }, 2),
                  _dashboardCard(Icons.settings, "Settings", () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => AdminSettingsScreen()));
                  }, 3),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashboardCard(IconData icon, String title, VoidCallback onTap, int index) {
    final intervalStart = index * 0.2;
    final intervalEnd = intervalStart + 0.6;

    final curved = CurvedAnimation(
      parent: _animationController,
      curve: Interval(intervalStart, intervalEnd, curve: Curves.easeOut),
    );

    return ScaleTransition(
      scale: Tween<double>(begin: 0.8, end: 1.0).animate(curved),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
        child: _GlowCard(icon: icon, title: title, onTap: onTap),
      ),
    );
  }
}
class _GlowCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _GlowCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  State<_GlowCard> createState() => _GlowCardState();
}

class _GlowCardState extends State<_GlowCard> {
  bool isGlowing = false;

  void _triggerGlow(bool glow) {
    setState(() => isGlowing = glow);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _triggerGlow(true),
      onTapUp: (_) {
        _triggerGlow(false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => _triggerGlow(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: isGlowing
              ? [
            BoxShadow(
              color: Colors.white.withOpacity(0.6),
              blurRadius: 15,
              spreadRadius: 4,
            )
          ]
              : [],
        ),
        child: Card(
          elevation: 5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 50, color: Colors.blue),
              const SizedBox(height: 10),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
