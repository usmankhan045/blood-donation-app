import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_profile_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool? profileCompleted;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    fetchProfileStatus();
  }

  Future<void> fetchProfileStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => profileCompleted = false);
      return;
    }
    try {
      setState(() => _loading = true);
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!mounted) return;
      setState(() {
        profileCompleted = (doc.data()?['profileCompleted'] ?? false) as bool;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => profileCompleted = false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
    );
    if (mounted) fetchProfileStatus();
  }

  void _openProfileCompletion() {
    Navigator.pushNamed(context, '/admin_profile_completion').then((_) => fetchProfileStatus());
  }

  @override
  Widget build(BuildContext context) {
    if (profileCompleted == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Dashboard')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final bool isComplete = profileCompleted ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FB),
      appBar: AppBar(
        elevation: 0,
        title: const Text('Admin Dashboard'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF67D5B5), Color(0xFF4AB9C5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned(top: -60, left: -40, child: _blob(140, const Color(0x3367D5B5))),
          Positioned(bottom: -50, right: -30, child: _blob(120, const Color(0x334AB9C5))),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeaderCard(
                    isComplete: isComplete,
                    onProfileTap: _openProfile,
                    onCompleteTap: _openProfileCompletion,
                    loading: _loading,
                  ),
                  const SizedBox(height: 18),

                  // Quick stats (lightweight, non-blocking)
                  _StatsRow(),

                  const SizedBox(height: 18),

                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      childAspectRatio: 0.93,
                      mainAxisSpacing: 18,
                      crossAxisSpacing: 18,
                      children: [
                        _featureTile(
                          icon: Icons.people,
                          title: "Manage Users",
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Manage Users – coming soon')),
                            );
                          },
                        ),
                        _featureTile(
                          icon: Icons.analytics_outlined,
                          title: "Reports",
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Reports – coming soon')),
                            );
                          },
                        ),
                        _featureTile(
                          icon: Icons.settings,
                          title: "System Settings",
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Settings – coming soon')),
                            );
                          },
                        ),
                        _featureTile(
                          icon: Icons.account_circle,
                          title: "My Profile",
                          onTap: _openProfile,
                        ),
                      ],
                    ),
                  ),

                  if (!isComplete)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        "Complete your profile to access all features.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.red[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(double size, Color color) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }

  Widget _featureTile({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
  }) {
    final borderRadius = BorderRadius.circular(18);

    final outer = Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF67D5B5), Color(0xFF4AB9C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );

    final inner = Container(
      margin: const EdgeInsets.all(1.4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFE3F7F2), Color(0xFFD2F1F3)],
              ),
            ),
            child: const Icon(Icons.apps, color: Color(0xFF30B7A2), size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15.5,
              color: Colors.blueGrey[900],
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );

    return Stack(
      children: [
        outer,
        inner,
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: borderRadius,
              splashColor: const Color(0x2167D5B5),
              highlightColor: const Color(0x1167D5B5),
              onTap: onTap,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final bool isComplete;
  final VoidCallback onProfileTap;
  final VoidCallback onCompleteTap;
  final bool loading;

  const _HeaderCard({
    required this.isComplete,
    required this.onProfileTap,
    required this.onCompleteTap,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF67D5B5), Color(0xFF4AB9C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF67D5B5).withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.45)),
                ),
                child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _chip(isComplete ? 'Complete' : 'Incomplete',
                        color: Colors.white,
                        textColor: isComplete ? const Color(0xFF2C8D7C) : Colors.black87),
                    _chip('Role: Admin', color: Colors.white, textColor: Colors.black87),
                  ],
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onProfileTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                  ),
                  icon: const Icon(Icons.account_circle),
                  label: const Text('My Profile'),
                ),
              ),
              const SizedBox(width: 10),
              if (!isComplete)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onCompleteTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF2C8D7C),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Complete Profile'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, {Color color = Colors.white, Color textColor = Colors.black87}) {
    return Chip(
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
      ),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // lightweight live counters (donors & recipients)
    return Row(
      children: const [
        Expanded(child: _CounterCard(title: 'Users', role: null)),
        SizedBox(width: 10),
        Expanded(child: _CounterCard(title: 'Donors', role: 'donor')),
        SizedBox(width: 10),
        Expanded(child: _CounterCard(title: 'Recipients', role: 'recipient')),
      ],
    );
  }
}

class _CounterCard extends StatelessWidget {
  final String title;
  final String? role; // null => all users

  const _CounterCard({required this.title, this.role});

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection('users');
    if (role != null) q = q.where('role', isEqualTo: role);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          final count = snap.hasData ? snap.data!.docs.length : 0;
          return Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFE3F7F2), Color(0xFFD2F1F3)],
                  ),
                ),
                child: const Icon(Icons.insights, color: Color(0xFF2C8D7C)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$title\n$count',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.blueGrey[900],
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
