import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BloodBankDashboardScreen extends StatefulWidget {
  const BloodBankDashboardScreen({Key? key}) : super(key: key);

  @override
  State<BloodBankDashboardScreen> createState() => _BloodBankDashboardScreenState();
}

class _BloodBankDashboardScreenState extends State<BloodBankDashboardScreen> {
  bool? profileCompleted;

  @override
  void initState() {
    super.initState();
    fetchProfileStatus();
  }

  Future<void> fetchProfileStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    setState(() {
      profileCompleted = doc.data()?['profileCompleted'] ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (profileCompleted == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Blood Bank Dashboard')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FB),
      appBar: AppBar(
        title: const Text('Blood Bank Dashboard'),
        backgroundColor: const Color(0xFF67D5B5),
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              color: Colors.white,
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                child: Row(
                  children: [
                    profileCompleted!
                        ? Icon(Icons.check_circle, color: Colors.green, size: 48)
                        : Icon(Icons.assignment_ind_outlined, color: Color(0xFF67D5B5), size: 48),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profileCompleted!
                                ? "Your profile is complete!"
                                : "Complete your profile to unlock features",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Colors.blueGrey[700],
                            ),
                          ),
                          const SizedBox(height: 7),
                          if (!profileCompleted!)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF67D5B5),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              ),
                              icon: Icon(Icons.assignment_ind_outlined),
                              label: Text("Complete Profile"),
                              onPressed: () async {
                                final updated = await Navigator.pushNamed(context, '/blood_bank_profile_completion');
                                fetchProfileStatus();
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 0.93,
                mainAxisSpacing: 18,
                crossAxisSpacing: 18,
                children: [
                  _buildFeatureTile(
                    icon: Icons.inventory,
                    title: "Manage Inventory",
                    enabled: profileCompleted ?? false,
                  ),
                  _buildFeatureTile(
                    icon: Icons.list_alt,
                    title: "Requests",
                    enabled: profileCompleted ?? false,
                  ),
                  _buildFeatureTile(
                    icon: Icons.notifications_active,
                    title: "Alerts",
                    enabled: profileCompleted ?? false,
                  ),
                  _buildFeatureTile(
                    icon: Icons.account_circle,
                    title: "Profile",
                    enabled: true,
                    onTap: () {
                      Navigator.pushNamed(context, '/blood_bank_profile_completion')
                          .then((_) => fetchProfileStatus());
                    },
                  ),
                ],
              ),
            ),
            if (!(profileCompleted ?? false))
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
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    bool enabled = true,
    VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
            boxShadow: [
              BoxShadow(
                  color: Colors.grey.withOpacity(0.08),
                  blurRadius: 7,
                  spreadRadius: 2)
            ],
            border: Border.all(
              color: enabled ? Color(0xFF67D5B5) : Colors.grey[300]!,
              width: 1.2,
            ),
          ),
          padding: EdgeInsets.all(19),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: enabled ? Color(0xFF67D5B5) : Colors.grey),
              const SizedBox(height: 13),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: enabled ? Colors.blueGrey[900] : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
