import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/fcm_service.dart';
import '../../../services/fulfillment_service.dart';
import '../../../repositories/chat_repository.dart';
import '../../../core/notification/dev_inbox_listener.dart';
import '../../../core/theme.dart';
import '../../chat/chat_screen.dart';

class HospitalDashboardScreen extends StatefulWidget {
  const HospitalDashboardScreen({Key? key}) : super(key: key);

  @override
  State<HospitalDashboardScreen> createState() =>
      _HospitalDashboardScreenState();
}

class _HospitalDashboardScreenState extends State<HospitalDashboardScreen> {
  bool? profileCompleted;
  Map<String, dynamic>? hospitalData;
  bool isLoading = true;
  int _activeRequestsCount = 0;
  int _acceptedRequestsCount = 0;
  int _completedRequestsCount = 0;

  @override
  void initState() {
    super.initState();
    fetchProfileStatus();
    _initializeNotifications();
    _startRealTimeListeners();
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

  void _startRealTimeListeners() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Active requests
    FirebaseFirestore.instance
        .collection('blood_requests')
        .where('requesterId', isEqualTo: user.uid)
        .where('status', whereIn: ['pending', 'active'])
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            setState(() => _activeRequestsCount = snapshot.docs.length);
          }
        });

    // Accepted requests
    FirebaseFirestore.instance
        .collection('blood_requests')
        .where('requesterId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            setState(() => _acceptedRequestsCount = snapshot.docs.length);
          }
        });

    // Completed requests
    FirebaseFirestore.instance
        .collection('blood_requests')
        .where('requesterId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            setState(() => _completedRequestsCount = snapshot.docs.length);
          }
        });
  }

  @override
  void dispose() {
    DevInboxListener.dispose();
    super.dispose();
  }

  Future<void> fetchProfileStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      setState(() {
        profileCompleted = doc.data()?['profileCompleted'] ?? false;
        hospitalData = doc.data();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.logout, color: BloodAppTheme.error),
            const SizedBox(width: 12),
            const Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: BloodAppTheme.error),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/select_role', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: BloodAppTheme.background,
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(BloodAppTheme.primary),
          ),
        ),
      );
    }

    if (profileCompleted == false) {
      return _buildProfileIncompleteScreen();
    }

    return Scaffold(
      backgroundColor: BloodAppTheme.background,
      body: Stack(
        children: [
          // Background decorative elements
          Positioned(
            top: -100,
            right: -80,
            child: _blob(200, BloodAppTheme.primary.withOpacity(0.1)),
          ),
          Positioned(
            bottom: -60,
            left: -40,
            child: _blob(160, BloodAppTheme.accent.withOpacity(0.1)),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 200,
                  floating: false,
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(background: _buildHeader()),
                  actions: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/hospital_profile_completion',
                        ).then((_) => fetchProfileStatus());
                      },
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.logout, color: Colors.white, size: 22),
                      ),
                      onPressed: _logout,
                      tooltip: 'Logout',
                    ),
                    const SizedBox(width: 8),
                  ],
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stats Section
                        const SizedBox(height: 16),
                        _buildStatsSection(),

                        // Accepted Requests - Ready to Complete
                        if (_acceptedRequestsCount > 0) ...[
                          const SizedBox(height: 20),
                          _buildAcceptedRequestsSection(),
                        ],

                        // Quick Actions
                        const SizedBox(height: 24),
                        _buildQuickActionsHeader(),
                        const SizedBox(height: 12),
                        _buildQuickActions(),

                        // Info Card
                        const SizedBox(height: 24),
                        _buildInfoCard(),

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
      floatingActionButton:
          profileCompleted == true
              ? FloatingActionButton.extended(
                onPressed:
                    () => Navigator.pushNamed(context, '/hospital/request'),
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

  Widget _buildProfileIncompleteScreen() {
    return Scaffold(
      backgroundColor: BloodAppTheme.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: BloodAppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_hospital,
                    size: 64,
                    color: BloodAppTheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Complete Your Profile',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: BloodAppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Please complete your hospital profile to access all features and start requesting blood.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: BloodAppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
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
                  icon: const Icon(Icons.edit),
                  label: const Text(
                    'Complete Profile Now',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    await Navigator.pushNamed(
                      context,
                      '/hospital_profile_completion',
                    );
                    fetchProfileStatus();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
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
                  child: const Icon(
                    Icons.local_hospital,
                    color: Colors.white,
                    size: 24,
                  ),
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
                        hospitalData?['hospitalName'] ??
                            hospitalData?['fullName'] ??
                            'Hospital',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _activeRequestsCount > 0
                        ? Icons.pending
                        : Icons.check_circle,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _activeRequestsCount > 0
                        ? '$_activeRequestsCount active requests'
                        : 'No active requests',
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

  Widget _buildStatsSection() {
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
                child: const Icon(
                  Icons.analytics,
                  color: BloodAppTheme.primary,
                  size: 22,
                ),
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
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Active',
                  _activeRequestsCount,
                  BloodAppTheme.warning,
                  Icons.pending_actions,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatItem(
                  'Accepted',
                  _acceptedRequestsCount,
                  BloodAppTheme.info,
                  Icons.handshake,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatItem(
                  'Completed',
                  _completedRequestsCount,
                  BloodAppTheme.success,
                  Icons.check_circle,
                ),
              ),
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

  Widget _buildAcceptedRequestsSection() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: BloodAppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle, color: BloodAppTheme.success, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Ready to Complete',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: BloodAppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('blood_requests')
              .where('requesterId', isEqualTo: userId)
              .where('status', isEqualTo: 'accepted')
              .orderBy('acceptedAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const SizedBox.shrink();
            }

            return Column(
              children: snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _buildAcceptedRequestCard(doc.id, data);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAcceptedRequestCard(String requestId, Map<String, dynamic> data) {
    final bloodType = data['bloodType'] as String? ?? 'Unknown';
    final units = (data['units'] as num?)?.toInt() ?? 1;
    final acceptedByName = data['acceptedBloodBankName'] as String? ?? 
                           data['acceptedByName'] as String? ?? 
                           'Blood Bank';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [BloodAppTheme.success, BloodAppTheme.success.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: BloodAppTheme.success.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.water_drop,
                        color: BloodAppTheme.getBloodTypeColor(bloodType),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        bloodType,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: BloodAppTheme.getBloodTypeColor(bloodType),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$units unit${units > 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'ACCEPTED',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.local_hospital,
                  color: Colors.white.withOpacity(0.9),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Accepted by: $acceptedByName',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openChat(requestId, data),
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('Chat'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _completeDonation(requestId, data),
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Complete Donation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: BloodAppTheme.success,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openChat(String requestId, Map<String, dynamic> data) {
    final acceptedByName = data['acceptedBloodBankName'] as String? ?? 
                           data['acceptedByName'] as String? ?? 
                           'Blood Bank';
    final bloodType = data['bloodType'] as String? ?? '';
    final units = (data['units'] as num?)?.toInt() ?? 1;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          threadId: requestId,
          title: acceptedByName,
          subtitle: '$bloodType Blood Request - $units unit(s)',
          otherUserName: acceptedByName,
          otherUserId: data['acceptedBy'] as String?,
          bloodType: bloodType,
          units: units,
        ),
      ),
    );
  }

  Future<void> _completeDonation(String requestId, Map<String, dynamic> data) async {
    final bloodType = data['bloodType'] as String? ?? '';
    final units = (data['units'] as num?)?.toInt() ?? 1;
    final acceptedByName = data['acceptedBloodBankName'] as String? ?? 
                           data['acceptedByName'] as String? ?? 
                           'Blood Bank';
    final acceptedBy = data['acceptedBy'] as String?;
    final hospitalName = hospitalData?['hospitalName'] as String? ?? 'Hospital';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: BloodAppTheme.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: BloodAppTheme.success),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Complete Donation?')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Blood Type: $bloodType'),
            Text('Units: $units'),
            Text('Provided by: $acceptedByName'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BloodAppTheme.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: BloodAppTheme.info, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will mark the donation as complete and notify the blood bank to deduct inventory.',
                      style: TextStyle(fontSize: 12, color: BloodAppTheme.info),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: BloodAppTheme.success),
            child: const Text('Complete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Update blood request status
      await FirebaseFirestore.instance
          .collection('blood_requests')
          .doc(requestId)
          .update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Mark chat thread as completed
      await ChatRepository().markThreadAsCompleted(requestId);

      // Send inventory deduction notification to blood bank
      if (acceptedBy != null) {
        await FulfillmentService.instance.requestInventoryDeductionConfirmation(
          requestId: requestId,
          bloodBankId: acceptedBy,
          bloodType: bloodType,
          units: units,
          requesterName: hospitalName,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Donation completed successfully! 🎉'),
              ],
            ),
            backgroundColor: BloodAppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: BloodAppTheme.error,
          ),
        );
      }
    }
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

  Widget _buildQuickActions() {
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
            enabled: profileCompleted == true,
            onTap: () => Navigator.pushNamed(context, '/hospital/request'),
          ),
          Divider(
            height: 1,
            indent: 70,
            endIndent: 16,
            color: Colors.grey.shade200,
          ),
          _buildQuickActionTile(
            icon: Icons.list_alt,
            title: 'My Requests',
            subtitle:
                _activeRequestsCount > 0
                    ? '$_activeRequestsCount active, $_acceptedRequestsCount accepted'
                    : 'View your blood requests',
            iconColor: BloodAppTheme.primary,
            enabled: profileCompleted == true,
            onTap: () => Navigator.pushNamed(context, '/hospital/my_requests'),
            badge: _activeRequestsCount + _acceptedRequestsCount,
          ),
          Divider(
            height: 1,
            indent: 70,
            endIndent: 16,
            color: Colors.grey.shade200,
          ),
          _buildQuickActionTile(
            icon: Icons.chat_bubble_outline,
            title: 'Messages',
            subtitle: 'Chat with blood banks',
            iconColor: BloodAppTheme.success,
            enabled: profileCompleted == true,
            onTap: () => Navigator.pushNamed(context, '/chats'),
          ),
          Divider(
            height: 1,
            indent: 70,
            endIndent: 16,
            color: Colors.grey.shade200,
          ),
          _buildQuickActionTile(
            icon: Icons.person,
            title: 'Profile Settings',
            subtitle:
                profileCompleted == true
                    ? 'View & edit profile'
                    : 'Complete your profile',
            iconColor: BloodAppTheme.info,
            enabled: true,
            onTap:
                () => Navigator.pushNamed(
                  context,
                  '/hospital_profile_completion',
                ).then((_) => fetchProfileStatus()),
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
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              badge > 9 ? '9+' : badge.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: BloodAppTheme.warning,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Required',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
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
                Icon(
                  Icons.chevron_right,
                  color: BloodAppTheme.textHint,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BloodAppTheme.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BloodAppTheme.info.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: BloodAppTheme.info.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.info, color: BloodAppTheme.info, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hospital Blood Requests',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: BloodAppTheme.info,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your requests are sent to blood banks in your area for faster fulfillment.',
                  style: TextStyle(
                    color: BloodAppTheme.info.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
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
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
