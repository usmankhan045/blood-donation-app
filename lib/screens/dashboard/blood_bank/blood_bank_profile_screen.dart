import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../services/auth_service.dart';
import 'blood_bank_profile_completion_screen.dart';

class BloodBankProfileScreen extends StatefulWidget {
  const BloodBankProfileScreen({super.key});

  @override
  State<BloodBankProfileScreen> createState() => _BloodBankProfileScreenState();
}

class _BloodBankProfileScreenState extends State<BloodBankProfileScreen> {
  final _auth = FirebaseAuth.instance;
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Profile')),
        body: const Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      backgroundColor: BloodAppTheme.background,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(BloodAppTheme.primary),
              ),
            );
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Profile not found.'));
          }

          final data = (snap.data!.data() as Map<String, dynamic>?) ?? {};
          final verified = (data['isVerified'] ?? false) as bool;
          final completed = (data['profileCompleted'] ?? false) as bool;
          final profileCompletedAt = data['profileCompletedAt'] as Timestamp?;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(data, verified, completed),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Stats Cards
                      _buildStatsRow(data),
                      const SizedBox(height: 20),

                      // Profile Sections
                      _buildViewSection(data, verified, completed, profileCompletedAt),

                      const SizedBox(height: 24),

                      // Action Buttons
                      if (!_editing) ...[
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BloodBankProfileCompletionScreen(),
                              ),
                            ).then((_) => setState(() {}));
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit Profile'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BloodAppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _showSignOutDialog,
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign Out'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: BloodAppTheme.error,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: const BorderSide(color: BloodAppTheme.error),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBar(
    Map<String, dynamic> data,
    bool verified,
    bool completed,
  ) {
    final name = data['bloodBankName'] ?? 'Blood Bank';
    final email = data['email'] ?? '';

    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: BloodAppTheme.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [BloodAppTheme.primary, BloodAppTheme.primaryDark],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                        ),
                        child: const Icon(
                          Icons.local_hospital,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildStatusChip(
                        completed ? 'Complete' : 'Incomplete',
                        completed ? BloodAppTheme.success : BloodAppTheme.warning,
                        completed ? Icons.check_circle : Icons.pending,
                      ),
                      _buildStatusChip(
                        verified ? 'Verified' : 'Unverified',
                        verified ? BloodAppTheme.info : BloodAppTheme.textSecondary,
                        verified ? Icons.verified_user : Icons.verified_user_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Map<String, dynamic> data) {
    final totalUnits = _getTotalUnits(data);
    final lowStock = _getLowStockCount(data);
    final outOfStock = _getOutOfStockCount(data);

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Units',
            totalUnits.toString(),
            Icons.inventory_2,
            BloodAppTheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Low Stock',
            lowStock.toString(),
            Icons.warning,
            BloodAppTheme.warning,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Out of Stock',
            outOfStock.toString(),
            Icons.block,
            BloodAppTheme.error,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: BloodAppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: BloodAppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildViewSection(
    Map<String, dynamic> data,
    bool verified,
    bool completed,
    Timestamp? profileCompletedAt,
  ) {
    return Column(
      children: [
        _buildInfoCard(
          title: 'Blood Bank Information',
          icon: Icons.local_hospital,
          items: [
            _InfoItem('Blood Bank Name', data['bloodBankName'] ?? 'Not set'),
            _InfoItem('Type', data['bloodBankType'] ?? 'Not set'),
            _InfoItem('Registration No.', data['registrationNo'] ?? 'Not set'),
            _InfoItem('City', data['city'] ?? 'Not set'),
            _InfoItem('Address', data['address'] ?? 'Not set'),
            if (data['operatingHours'] != null)
              _InfoItem('Operating Hours', data['operatingHours']),
            if (data['available24Hours'] == true)
              _InfoItem('Availability', '24/7'),
            if (data['acceptsDonations'] != null)
              _InfoItem(
                'Accepts Donations',
                data['acceptsDonations'] == true ? 'Yes' : 'No',
              ),
          ],
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          title: 'Contact Information',
          icon: Icons.contact_phone,
          items: [
            _InfoItem('Contact Person', data['contactPerson'] ?? 'Not set'),
            _InfoItem('Designation', data['designation'] ?? 'Not set'),
            _InfoItem('Phone', data['phoneNumber'] ?? 'Not set'),
            _InfoItem('Email', data['email'] ?? 'Not set'),
            if (data['emergencyPhone'] != null)
              _InfoItem('Emergency Phone', data['emergencyPhone']),
          ],
        ),
        const SizedBox(height: 16),
        if (data['availableBloodTypes'] != null) ...[
          _buildInfoCard(
            title: 'Available Blood Types',
            icon: Icons.bloodtype,
            items: [
              _InfoItem(
                'Types',
                (data['availableBloodTypes'] as List).join(', '),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        _buildInfoCard(
          title: 'Account Status',
          icon: Icons.verified_user,
          items: [
            _InfoItem('Profile', completed ? 'Complete ✓' : 'Incomplete'),
            _InfoItem('Verification', verified ? 'Verified ✓' : 'Pending'),
            _InfoItem('Role', 'Blood Bank'),
            if (profileCompletedAt != null)
              _InfoItem(
                'Completed On',
                _formatDate(profileCompletedAt.toDate()),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<_InfoItem> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: BloodAppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BloodAppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: BloodAppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: BloodAppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 14,
                          color: BloodAppTheme.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.value,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: item.highlight
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: item.highlight
                              ? BloodAppTheme.primary
                              : BloodAppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  int _getTotalUnits(Map<String, dynamic> data) {
    if (data['inventory'] == null) return 0;
    final inventory = data['inventory'] as Map<String, dynamic>;
    int total = 0;
    inventory.forEach((key, value) {
      if (value is Map && value['units'] != null) {
        total += (value['units'] as num).toInt();
      }
    });
    return total;
  }

  int _getLowStockCount(Map<String, dynamic> data) {
    if (data['inventory'] == null) return 0;
    final inventory = data['inventory'] as Map<String, dynamic>;
    int count = 0;
    inventory.forEach((key, value) {
      if (value is Map && value['units'] != null) {
        final units = (value['units'] as num).toInt();
        if (units > 0 && units < 5) count++;
      }
    });
    return count;
  }

  int _getOutOfStockCount(Map<String, dynamic> data) {
    if (data['inventory'] == null) return 0;
    final inventory = data['inventory'] as Map<String, dynamic>;
    int count = 0;
    inventory.forEach((key, value) {
      if (value is Map && value['units'] != null) {
        final units = (value['units'] as num).toInt();
        if (units == 0) count++;
      }
    });
    return count;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _showSignOutDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BloodAppTheme.radiusLg),
        ),
        title: Row(
          children: [
            const Icon(Icons.logout, color: BloodAppTheme.error),
            const SizedBox(width: 12),
            const Text('Sign Out'),
          ],
        ),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: BloodAppTheme.error,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService().signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/select_role',
          (route) => false,
        );
      }
    }
  }
}

class _InfoItem {
  final String label;
  final String value;
  final bool highlight;

  _InfoItem(this.label, this.value, {this.highlight = false});
}

