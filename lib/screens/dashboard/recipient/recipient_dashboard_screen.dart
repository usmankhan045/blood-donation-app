import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RecipientDashboardScreen extends StatefulWidget {
  const RecipientDashboardScreen({Key? key}) : super(key: key);

  @override
  State<RecipientDashboardScreen> createState() => _RecipientDashboardScreenState();
}

class _RecipientDashboardScreenState extends State<RecipientDashboardScreen> {
  bool? profileCompleted;

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
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!mounted) return; // avoid setState after dispose
      setState(() {
        profileCompleted = (doc.data()?['profileCompleted'] ?? false) as bool;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => profileCompleted = false);
    }
  }

  void _openRequestBlood() {
    Navigator.pushNamed(context, '/recipient/request');
  }

  void _openMyRequests() {
    Navigator.pushNamed(context, '/recipient/my_requests');
  }

  void _openAlerts() {
    Navigator.pushNamed(context, '/recipient/alerts');
  }

  // keep completion flow as a separate route (your existing screen)
  void _openProfileCompletion() async {
    await Navigator.pushNamed(context, '/recipient_profile_completion');
    fetchProfileStatus();
  }

  // open the new viewer/editor screen
  void _openProfile() {
    Navigator.pushNamed(context, '/recipient/profile');
  }

  @override
  Widget build(BuildContext context) {
    if (profileCompleted == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recipient Dashboard')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final canUseFeatures = profileCompleted ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FB),
      appBar: AppBar(
        elevation: 0,
        title: const Text('Recipient Dashboard'),
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
      floatingActionButton: canUseFeatures
          ? FloatingActionButton.extended(
        onPressed: _openRequestBlood,
        icon: const Icon(Icons.add),
        label: const Text('Request Blood'),
        backgroundColor: const Color(0xFF67D5B5),
      )
          : null,
      body: Stack(
        children: [
          // Decorative background blobs
          Positioned(
            top: -60,
            left: -40,
            child: _blob(140, const Color(0x3367D5B5)),
          ),
          Positioned(
            bottom: -50,
            right: -30,
            child: _blob(120, const Color(0x334AB9C5)),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeaderCard(
                    isComplete: profileCompleted!,
                    onCompleteTap: _openProfileCompletion, // <-- go to completion flow
                  ),
                  const SizedBox(height: 22),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      childAspectRatio: 0.93,
                      mainAxisSpacing: 18,
                      crossAxisSpacing: 18,
                      children: [
                        _buildFeatureTile(
                          icon: Icons.bloodtype,
                          title: "Request Blood",
                          enabled: canUseFeatures,
                          onTap: _openRequestBlood,
                        ),
                        _buildFeatureTile(
                          icon: Icons.history,
                          title: "My Requests",
                          enabled: canUseFeatures,
                          onTap: _openMyRequests,
                        ),
                        _buildFeatureTile(
                          icon: Icons.notifications_active,
                          title: "Alerts",
                          enabled: canUseFeatures,
                          onTap: _openAlerts,
                          badge: true, // small visual hint; no logic change
                        ),
                        _buildFeatureTile(
                          icon: Icons.account_circle,
                          title: "My Profile",
                          enabled: true, // Always accessible
                          onTap: _openProfile, // <-- open viewer/editor
                        ),
                      ],
                    ),
                  ),
                  if (!canUseFeatures)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
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

  // ---------- UI helpers below (visual upgrades only) ----------

  Widget _blob(double size, Color color) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    bool enabled = true,
    VoidCallback? onTap,
    bool badge = false,
  }) {
    final borderRadius = BorderRadius.circular(18);

    // Gradient border illusion: outer gradient + inner white card
    final outer = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: enabled
              ? const [Color(0xFF67D5B5), Color(0xFF4AB9C5)]
              : [Colors.grey.shade300, Colors.grey.shade300],
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
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: enabled
                        ? const [Color(0xFFE3F7F2), Color(0xFFD2F1F3)]
                        : [Colors.grey.shade200, Colors.grey.shade200],
                  ),
                ),
                child: Icon(
                  icon,
                  size: 30,
                  color: enabled ? const Color(0xFF30B7A2) : Colors.grey,
                ),
              ),
              if (badge)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: enabled ? const Color(0xFFEF5350) : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15.5,
              color: enabled ? Colors.blueGrey[900] : Colors.grey,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );

    final tile = AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.42,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: 1.0,
        child: Stack(
          children: [
            outer,
            inner,
            // ripple on tap (material ink effect)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: borderRadius,
                  splashColor: enabled ? const Color(0x2167D5B5) : Colors.transparent,
                  highlightColor: enabled ? const Color(0x1167D5B5) : Colors.transparent,
                  onTap: enabled ? onTap : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return tile;
  }
}

class _HeaderCard extends StatelessWidget {
  final bool isComplete;
  final VoidCallback onCompleteTap;

  const _HeaderCard({
    required this.isComplete,
    required this.onCompleteTap,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = const LinearGradient(
      colors: [Color(0xFF67D5B5), Color(0xFF4AB9C5)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF67D5B5).withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.45)),
            ),
            child: Icon(
              isComplete ? Icons.verified_rounded : Icons.assignment_ind_outlined,
              size: 30,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _HeaderText(isComplete: isComplete),
          ),
          if (!isComplete)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2C8D7C),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onPressed: onCompleteTap,
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text(
                'Complete Profile',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final bool isComplete;
  const _HeaderText({required this.isComplete});

  @override
  Widget build(BuildContext context) {
    final title = isComplete ? "Your profile is complete!" : "Complete your profile to unlock features";
    final subtitle = isComplete
        ? "You can now request blood and view your requests."
        : "Finish a few details so we can enable all features.";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16.5,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
