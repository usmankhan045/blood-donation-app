import 'dart:ui' show ImageFilter;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../services/donor_service.dart';
import '../../../repositories/blood_request_repository.dart';
import '../../../models/blood_request_model.dart';
import '../../chat/chat_screen.dart';
import 'donor_profile_screen.dart';
import 'donor_requests_screen.dart';

class DonorDashboardScreen extends StatefulWidget {
  const DonorDashboardScreen({super.key});

  @override
  State<DonorDashboardScreen> createState() => _DonorDashboardScreenState();
}

class _DonorDashboardScreenState extends State<DonorDashboardScreen> {
  final _donorService = DonorService();
  final _auth = FirebaseAuth.instance;

  bool _isAvailable = false;
  bool _profileCompleted = false;
  String? _city;
  String? _bloodType;
  String? _donorName;
  bool _navigating = false;
  int _totalDonations = 0;
  int _pendingRequests = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadStats();
  }

  Future<void> _loadProfile() async {
    final uid = _auth.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final d = doc.data() ?? {};
    if (!mounted) return;
    setState(() {
      _isAvailable = (d['isAvailable'] ?? false) as bool;
      _profileCompleted = (d['profileCompleted'] ?? false) as bool;
      _city = d['city'] as String?;
      _bloodType = (d['bloodGroup'] ?? d['bloodType'] as String?)?.toUpperCase();
      _donorName = d['fullName'] as String?;
    });
  }

  Future<void> _loadStats() async {
    final stats = await _donorService.getDonorStats();
    if (mounted) {
      setState(() {
        _totalDonations = stats['totalDonations'] ?? 0;
        _pendingRequests = stats['pendingRequests'] ?? 0;
      });
    }
  }

  Future<void> _toggle(bool v) async {
    await _donorService.toggleAvailability(v);
    if (!mounted) return;
    setState(() => _isAvailable = v);
  }

  Future<void> _openProfile() async {
    if (_navigating) return;
    _navigating = true;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DonorProfileScreen()),
    );
    _navigating = false;
    if (mounted) {
      await _loadProfile();
      await _loadStats();
    }
  }

  void _openProfileCompletion() {
    Navigator.pushNamed(context, '/donor_profile_completion').then((_) {
      _loadProfile();
      _loadStats();
    });
  }

  void _openRequestsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DonorRequestsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = _profileCompleted;
    final canReceive = ready && _isAvailable && _city != null && _bloodType != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FB),
      appBar: AppBar(
        elevation: 0,
        title: const Text('Donor Dashboard'),
        centerTitle: true,
        backgroundColor: const Color(0xFF67D5B5),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'My Profile',
            icon: const Icon(Icons.account_circle),
            onPressed: _openProfile,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background decorative elements
          Positioned(top: -80, left: -60, child: _blob(160, const Color(0x1567D5B5))),
          Positioned(bottom: -70, right: -50, child: _blob(140, const Color(0x154AB9C5))),
          Positioned(top: 100, right: -30, child: _blob(80, const Color(0x15FF6B6B))),

          SafeArea(
            child: SingleChildScrollView( // Wrap with SingleChildScrollView
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Header
                  _buildWelcomeHeader(),
                  const SizedBox(height: 20),

                  // Stats Cards
                  _buildStatsRow(),
                  const SizedBox(height: 20),

                  // Availability Card
                  _buildAvailabilityCard(),
                  const SizedBox(height: 20),

                  // Quick Actions
                  _buildQuickActions(canReceive, ready),
                  const SizedBox(height: 20),

                  // Recent Activity Header
                  _buildRecentActivityHeader(),
                  const SizedBox(height: 12),

                  // Recent Donations - Fixed height container
                  _buildRecentDonations(),
                  const SizedBox(height: 20), // Add bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back,',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _donorName?.split(' ').first ?? 'Donor',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ready to save lives today?',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.bloodtype,
            value: _totalDonations.toString(),
            label: 'Donations',
            color: const Color(0xFF67D5B5),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.pending_actions,
            value: _pendingRequests.toString(),
            label: 'Pending',
            color: const Color(0xFFFFA726),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.people,
            value: _totalDonations.toString(),
            label: 'Lives Saved',
            color: const Color(0xFFEF5350),
          ),
        ),
      ],
    );
  }

  Widget _buildAvailabilityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF67D5B5), Color(0xFF4AB9C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF67D5B5).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50, // Reduced size
            height: 50, // Reduced size
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Icon(
              _isAvailable ? Icons.volunteer_activism : Icons.volunteer_activism_outlined,
              color: Colors.white,
              size: 24, // Reduced icon size
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isAvailable ? 'Available to Donate' : 'Currently Unavailable',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16, // Reduced font size
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isAvailable
                      ? 'You will receive blood requests'
                      : 'Turn on to receive requests',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12, // Reduced font size
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 1.1, // Slightly reduced scale
            child: Switch(
              value: _isAvailable,
              onChanged: _toggle,
              activeColor: Colors.white,
              activeTrackColor: Colors.white.withOpacity(0.5),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.white.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool canReceive, bool ready) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.search,
                title: 'Find Requests',
                subtitle: 'Browse blood requests',
                color: const Color(0xFF67D5B5),
                onTap: _openRequestsScreen,
                enabled: canReceive,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.history,
                title: 'My History',
                subtitle: 'Donation records',
                color: const Color(0xFFFFA726),
                onTap: () {
                  // Navigate to history screen
                },
                enabled: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!ready)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12), // Reduced padding
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[100]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.orange[800], size: 20), // Smaller icon
                const SizedBox(width: 8), // Reduced spacing
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Complete Your Profile',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                          fontSize: 14, // Smaller font
                        ),
                      ),
                      const SizedBox(height: 2), // Reduced spacing
                      Text(
                        'Finish your profile to start receiving requests',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 11, // Smaller font
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _openProfileCompletion,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8), // Smaller button
                    minimumSize: Size.zero,
                  ),
                  child: Text(
                    'Complete',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontSize: 12, // Smaller font
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRecentActivityHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        TextButton(
          onPressed: () {
            // Navigate to full history
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
          ),
          child: const Text(
            'View All',
            style: TextStyle(
              color: Color(0xFF67D5B5),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentDonations() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return _buildEmptyState();

    return Container(
      height: 200, // Fixed height to prevent overflow
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('requests')
            .where('acceptedBy', isEqualTo: uid)
            .where('status', isEqualTo: 'completed')
            .orderBy('completedAt', descending: true)
            .limit(3) // Reduced limit
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final donations = snapshot.data!.docs;

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: donations.length,
            itemBuilder: (context, index) {
              final donation = donations[index];
              final data = donation.data() as Map<String, dynamic>;
              final completedAt = data['completedAt'] as Timestamp?;
              final bloodType = data['bloodType'] ?? 'Unknown';
              final hospital = data['hospital'] ?? 'Unknown Hospital';
              final units = data['units'] ?? 1;

              return Container(
                margin: const EdgeInsets.only(bottom: 6), // Reduced margin
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10), // Slightly smaller radius
                  elevation: 1, // Reduced elevation
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // Reduced padding
                    leading: Container(
                      width: 36, // Smaller leading
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF67D5B5).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.bloodtype,
                        color: const Color(0xFF67D5B5),
                        size: 18, // Smaller icon
                      ),
                    ),
                    title: Text(
                      hospital,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13, // Smaller font
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      completedAt != null
                          ? '${_formatDate(completedAt.toDate())} • $units unit(s)'
                          : '$units unit(s)',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11, // Smaller font
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // Smaller padding
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        bloodType,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 11, // Smaller font
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 120, // Fixed height for empty state
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bloodtype_outlined,
              size: 40, // Smaller icon
              color: Colors.grey[300],
            ),
            const SizedBox(height: 8),
            Text(
              'No Donations Yet',
              style: TextStyle(
                fontSize: 14, // Smaller font
                fontWeight: FontWeight.bold,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your donation history will appear here',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12, // Smaller font
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blob(double size, Color color) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${date.day}/${date.month}/${date.year}';
  }
}

// =================== Stat Card ===================
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12), // Reduced padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // Smaller radius
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, // Smaller container
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18), // Smaller icon
          ),
          const SizedBox(height: 8), // Reduced spacing
          Text(
            value,
            style: const TextStyle(
              fontSize: 20, // Smaller font
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 2), // Reduced spacing
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11, // Smaller font
            ),
          ),
        ],
      ),
    );
  }
}

// =================== Quick Action Card ===================
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12), // Smaller radius
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12), // Reduced padding
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled ? color.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: enabled ? color : Colors.grey,
                size: 20, // Smaller icon
              ),
              const SizedBox(height: 8), // Reduced spacing
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: enabled ? color : Colors.grey,
                  fontSize: 12, // Smaller font
                ),
              ),
              const SizedBox(height: 2), // Reduced spacing
              Text(
                subtitle,
                style: TextStyle(
                  color: enabled ? color.withOpacity(0.7) : Colors.grey,
                  fontSize: 10, // Smaller font
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}