import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/fcm_service.dart';
import '../../../core/notification/dev_inbox_listener.dart';
import '../../../core/theme.dart';

class RecipientDashboardScreen extends StatefulWidget {
  const RecipientDashboardScreen({super.key});

  @override
  State<RecipientDashboardScreen> createState() => _RecipientDashboardScreenState();
}

class _RecipientDashboardScreenState extends State<RecipientDashboardScreen>
    with SingleTickerProviderStateMixin {
  bool? profileCompleted;
  String? _userName;
  int _activeRequests = 0;
  int _acceptedRequests = 0;
  int _completedRequests = 0;
  int _expiredRequests = 0;
  String? _bloodType;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    
    fetchProfileStatus();
    _loadUserData();
    _startRealTimeStats();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FCMService().saveFCMTokenToUser(user.uid);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        DevInboxListener.attach(context);
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    DevInboxListener.dispose();
    super.dispose();
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
      if (!mounted) return;
      setState(() {
        profileCompleted = (doc.data()?['profileCompleted'] ?? false) as bool;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => profileCompleted = false);
    }
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (mounted) {
          setState(() {
            _userName = doc.data()?['fullName'] as String?;
            _bloodType = doc.data()?['bloodGroup'] as String?;
          });
        }
      } catch (e) {
        debugPrint('Error loading user data: $e');
      }
    }
  }

  void _startRealTimeStats() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Real-time listener for requests
    FirebaseFirestore.instance
        .collection('blood_requests')
        .where('requesterId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      int active = 0;
      int accepted = 0;
      int completed = 0;
      int expired = 0;

      for (var doc in snapshot.docs) {
        final status = doc.data()['status'] as String?;
        final expiresAt = doc.data()['expiresAt'] as Timestamp?;
        
        // Check for active/pending status
        if (status == 'active' || status == 'pending') {
          if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
            expired++;
          } else {
            active++;
          }
        } else if (status == 'accepted') {
          accepted++;
        } else if (status == 'completed') {
          completed++;
        } else if (status == 'expired' || status == 'cancelled') {
          expired++;
        }
      }

      setState(() {
        _activeRequests = active;
        _acceptedRequests = accepted;
        _completedRequests = completed;
        _expiredRequests = expired;
      });
    });
  }

  void _openRequestBlood() {
    Navigator.pushNamed(context, '/recipient/request');
  }

  void _openMyRequests() {
    Navigator.pushNamed(context, '/recipient/my_requests');
  }

  void _openProfileCompletion() async {
    await Navigator.pushNamed(context, '/recipient_profile_completion');
    fetchProfileStatus();
  }

  void _openProfile() {
    Navigator.pushNamed(context, '/recipient/profile');
  }

  @override
  Widget build(BuildContext context) {
    if (profileCompleted == null) {
      return Scaffold(
        backgroundColor: BloodAppTheme.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(BloodAppTheme.primary),
              ),
              const SizedBox(height: 16),
              const Text('Loading...'),
            ],
          ),
        ),
      );
    }

    final canUseFeatures = profileCompleted ?? false;

    return Scaffold(
      backgroundColor: BloodAppTheme.background,
      body: Stack(
        children: [
          // Background decorative elements
          Positioned(top: -100, right: -80, child: _blob(200, BloodAppTheme.primary.withOpacity(0.1))),
          Positioned(bottom: -60, left: -40, child: _blob(160, BloodAppTheme.accent.withOpacity(0.1))),
          Positioned(top: 200, left: -50, child: _blob(120, BloodAppTheme.info.withOpacity(0.08))),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // App Bar
                SliverAppBar(
                  expandedHeight: 200,
                  floating: false,
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    background: _buildHeader(),
                  ),
                  actions: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 22),
                      ),
                      onPressed: _openProfile,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),

                // Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Status Card
                        if (!canUseFeatures) ...[
                          const SizedBox(height: 16),
                          _buildProfileIncompleteCard(),
                        ],

                        // Real-time Stats
                        if (canUseFeatures) ...[
                          const SizedBox(height: 16),
                          _buildRealTimeStats(),
                        ],

                        // Blood Type Card
                        if (_bloodType != null && canUseFeatures) ...[
                          const SizedBox(height: 16),
                          _buildBloodTypeCard(),
                        ],

                        // Quick Actions
                        const SizedBox(height: 24),
                        _buildQuickActionsHeader(),
                        const SizedBox(height: 12),
                        _buildQuickActions(canUseFeatures),

                        // Recent Activity
                        if (canUseFeatures) ...[
                          const SizedBox(height: 24),
                          _buildRecentActivityHeader(),
                          const SizedBox(height: 12),
                          _buildRecentActivity(),
                        ],

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: canUseFeatures
          ? FloatingActionButton.extended(
              onPressed: _openRequestBlood,
              backgroundColor: BloodAppTheme.accent,
              elevation: 4,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Request Blood',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [BloodAppTheme.primary, BloodAppTheme.primaryDark],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.favorite, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        _userName?.split(' ').first ?? 'Recipient',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  profileCompleted == true ? Icons.verified : Icons.info,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  profileCompleted == true ? 'Profile Complete ✓' : 'Complete Profile',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileIncompleteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade400, Colors.deepOrange.shade400],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.warning_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Complete Your Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Finish setup to request blood',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _openProfileCompletion,
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Complete',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealTimeStats() {
    final total = _activeRequests + _acceptedRequests + _completedRequests + _expiredRequests;

    return Container(
      padding: const EdgeInsets.all(16),
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
                child: const Icon(Icons.analytics, color: BloodAppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                'Request Statistics',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: BloodAppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: BloodAppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Total: $total',
                  style: const TextStyle(
                    color: BloodAppTheme.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildStatItem('Active', _activeRequests, BloodAppTheme.warning, Icons.pending_actions)),
              const SizedBox(width: 10),
              Expanded(child: _buildStatItem('Accepted', _acceptedRequests, BloodAppTheme.info, Icons.handshake)),
              const SizedBox(width: 10),
              Expanded(child: _buildStatItem('Done', _completedRequests, BloodAppTheme.success, Icons.check_circle)),
              const SizedBox(width: 10),
              Expanded(child: _buildStatItem('Expired', _expiredRequests, BloodAppTheme.textSecondary, Icons.timer_off)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: BloodAppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBloodTypeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            BloodAppTheme.getBloodTypeColor(_bloodType ?? 'O+').withOpacity(0.15),
            BloodAppTheme.getBloodTypeColor(_bloodType ?? 'O+').withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: BloodAppTheme.getBloodTypeColor(_bloodType ?? 'O+').withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: BloodAppTheme.getBloodTypeColor(_bloodType ?? 'O+'),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                _bloodType ?? '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Blood Type',
                  style: TextStyle(
                    color: BloodAppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _bloodType ?? 'Not Set',
                  style: TextStyle(
                    color: BloodAppTheme.getBloodTypeColor(_bloodType ?? 'O+'),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.water_drop,
            color: BloodAppTheme.getBloodTypeColor(_bloodType ?? 'O+'),
            size: 32,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsHeader() {
    return const Text(
      'Quick Actions',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: BloodAppTheme.textPrimary,
      ),
    );
  }

  Widget _buildQuickActions(bool canUseFeatures) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: BloodAppTheme.cardShadow,
      ),
      child: Column(
        children: [
          _buildQuickActionTile(
            icon: Icons.add_circle,
            title: 'Request Blood',
            subtitle: 'Create a new blood request',
            iconColor: BloodAppTheme.accent,
            enabled: canUseFeatures,
            onTap: _openRequestBlood,
            showArrow: true,
          ),
          Divider(height: 1, indent: 70, endIndent: 16, color: Colors.grey.shade200),
          _buildQuickActionTile(
            icon: Icons.list_alt,
            title: 'My Requests',
            subtitle: _activeRequests > 0 
                ? '$_activeRequests active, $_acceptedRequests accepted'
                : 'View your blood requests',
            iconColor: BloodAppTheme.primary,
            enabled: canUseFeatures,
            onTap: _openMyRequests,
            badge: _activeRequests + _acceptedRequests,
            showArrow: true,
          ),
          Divider(height: 1, indent: 70, endIndent: 16, color: Colors.grey.shade200),
          _buildQuickActionTile(
            icon: Icons.person,
            title: 'My Profile',
            subtitle: profileCompleted == true ? 'View & edit profile' : 'Complete your profile',
            iconColor: BloodAppTheme.info,
            enabled: true,
            onTap: _openProfile,
            showArrow: true,
            showWarning: profileCompleted != true,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required bool enabled,
    required VoidCallback onTap,
    int badge = 0,
    bool showArrow = false,
    bool showWarning = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Stack(
                    children: [
                      Center(child: Icon(icon, color: iconColor, size: 24)),
                      if (badge > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: BloodAppTheme.error,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            child: Text(
                              badge > 9 ? '9+' : badge.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: BloodAppTheme.textPrimary,
                            ),
                          ),
                          if (showWarning) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: BloodAppTheme.warning,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Required',
                                style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: BloodAppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showArrow)
                  Icon(Icons.chevron_right, color: BloodAppTheme.textHint, size: 22),
              ],
            ),
          ),
        ),
      ),
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
            color: BloodAppTheme.textPrimary,
          ),
        ),
        TextButton(
          onPressed: _openMyRequests,
          child: const Text(
            'View All',
            style: TextStyle(
              color: BloodAppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return _buildEmptyActivity();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('blood_requests')
          .where('requesterId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyActivity();
        }

        return Column(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] as String? ?? 'active';
            final bloodType = data['bloodType'] as String? ?? 'Unknown';
            final createdAt = data['createdAt'] as Timestamp?;
            final hospital = data['hospital'] as String? ?? data['city'] as String? ?? 'N/A';

            return _buildActivityItem(
              bloodType: bloodType,
              status: status,
              location: hospital,
              date: createdAt?.toDate(),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildActivityItem({
    required String bloodType,
    required String status,
    required String location,
    DateTime? date,
  }) {
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'completed':
        statusColor = BloodAppTheme.success;
        statusIcon = Icons.check_circle;
        break;
      case 'accepted':
        statusColor = BloodAppTheme.info;
        statusIcon = Icons.handshake;
        break;
      case 'expired':
        statusColor = BloodAppTheme.textSecondary;
        statusIcon = Icons.timer_off;
        break;
      default:
        statusColor = BloodAppTheme.warning;
        statusIcon = Icons.pending;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: BloodAppTheme.getBloodTypeColor(bloodType).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                bloodType,
                style: TextStyle(
                  color: BloodAppTheme.getBloodTypeColor(bloodType),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: BloodAppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  date != null ? _formatDate(date) : 'N/A',
                  style: TextStyle(
                    color: BloodAppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivity() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.history,
            size: 48,
            color: BloodAppTheme.textSecondary.withOpacity(0.3),
          ),
          const SizedBox(height: 12),
          const Text(
            'No Activity Yet',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: BloodAppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your blood requests will appear here',
            style: TextStyle(
              color: BloodAppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(double size, Color color) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${date.day}/${date.month}/${date.year}';
  }
}
