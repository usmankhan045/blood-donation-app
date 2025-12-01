import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/fcm_service.dart';
import '../../../core/notification/dev_inbox_listener.dart';
import '../../../core/theme.dart';
import 'blood_bank_requests_screen.dart';

class BloodBankDashboardScreen extends StatefulWidget {
  const BloodBankDashboardScreen({Key? key}) : super(key: key);

  @override
  State<BloodBankDashboardScreen> createState() => _BloodBankDashboardScreenState();
}

class _BloodBankDashboardScreenState extends State<BloodBankDashboardScreen> {
  bool? profileCompleted;
  Map<String, dynamic>? bloodBankData;
  bool isLoading = true;
  int _incomingRequestsCount = 0;
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

    // Incoming requests
    FirebaseFirestore.instance
        .collection('blood_requests')
        .where('eligibleBloodBanks', arrayContains: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() => _incomingRequestsCount = snapshot.docs.length);
      }
    });

    // Accepted requests
    FirebaseFirestore.instance
        .collection('blood_requests')
        .where('acceptedBy', isEqualTo: user.uid)
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
        .where('acceptedBy', isEqualTo: user.uid)
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
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      setState(() {
        profileCompleted = doc.data()?['profileCompleted'] ?? false;
        bloodBankData = doc.data();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      setState(() => isLoading = false);
    }
  }

  int getTotalUnits() {
    if (bloodBankData == null || bloodBankData!['inventory'] == null) return 0;
    Map<String, dynamic> inventory = bloodBankData!['inventory'];
    int total = 0;
    inventory.forEach((bloodType, data) {
      if (data is Map && data.containsKey('units')) {
        total += (data['units'] as int);
      }
    });
    return total;
  }

  int getLowStockCount() {
    if (bloodBankData == null || bloodBankData!['inventory'] == null) return 0;
    Map<String, dynamic> inventory = bloodBankData!['inventory'];
    int count = 0;
    inventory.forEach((bloodType, data) {
      if (data is Map && data.containsKey('units')) {
        int units = data['units'] as int;
        if (units > 0 && units < 5) count++;
      }
    });
    return count;
  }

  int getOutOfStockCount() {
    if (bloodBankData == null || bloodBankData!['inventory'] == null) return 0;
    Map<String, dynamic> inventory = bloodBankData!['inventory'];
    int count = 0;
    inventory.forEach((bloodType, data) {
      if (data is Map && data.containsKey('units')) {
        int units = data['units'] as int;
        if (units == 0) count++;
      }
    });
    return count;
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
          Positioned(top: -100, right: -80, child: _blob(200, BloodAppTheme.primary.withOpacity(0.1))),
          Positioned(bottom: -60, left: -40, child: _blob(160, BloodAppTheme.accent.withOpacity(0.1))),
          
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
                      onPressed: () {
                        Navigator.pushNamed(context, '/blood_bank_profile_completion')
                            .then((_) => fetchProfileStatus());
                      },
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
                        // Incoming Requests Banner
                        if (_incomingRequestsCount > 0) ...[
                          const SizedBox(height: 16),
                          _buildIncomingRequestsBanner(),
                        ],
                        
                        // Stats Section
                        const SizedBox(height: 16),
                        _buildStatsSection(),
                        
                        // Inventory Summary
                        const SizedBox(height: 16),
                        _buildInventorySummary(),
                        
                        // Quick Actions
                        const SizedBox(height: 24),
                        _buildQuickActionsHeader(),
                        const SizedBox(height: 12),
                        _buildQuickActions(),
                        
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
                  'Please complete your blood bank profile to access all features and start managing inventory.',
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
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
                    await Navigator.pushNamed(context, '/blood_bank_profile_completion');
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
                  child: const Icon(Icons.local_hospital, color: Colors.white, size: 24),
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
                        bloodBankData?['bloodBankName'] ?? 'Blood Bank',
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
                  const Icon(Icons.inventory_2, color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    '${getTotalUnits()} units in stock',
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

  Widget _buildIncomingRequestsBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BloodBankRequestsScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [BloodAppTheme.accent, BloodAppTheme.accentDark],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: BloodAppTheme.accent.withOpacity(0.4),
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
              child: const Icon(Icons.bloodtype, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_incomingRequestsCount New Request${_incomingRequestsCount > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to view and respond',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
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
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildStatItem('Pending', _incomingRequestsCount, BloodAppTheme.warning, Icons.pending_actions)),
              const SizedBox(width: 10),
              Expanded(child: _buildStatItem('Accepted', _acceptedRequestsCount, BloodAppTheme.info, Icons.handshake)),
              const SizedBox(width: 10),
              Expanded(child: _buildStatItem('Completed', _completedRequestsCount, BloodAppTheme.success, Icons.check_circle)),
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

  Widget _buildInventorySummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            BloodAppTheme.accent.withOpacity(0.15),
            BloodAppTheme.accent.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BloodAppTheme.accent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: BloodAppTheme.accent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Icon(Icons.inventory_2, color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Inventory Status',
                  style: TextStyle(
                    color: BloodAppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${getTotalUnits()} Total Units',
                  style: const TextStyle(
                    color: BloodAppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (getLowStockCount() > 0)
                      _buildInventoryBadge('${getLowStockCount()} Low', BloodAppTheme.warning),
                    if (getOutOfStockCount() > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _buildInventoryBadge('${getOutOfStockCount()} Empty', BloodAppTheme.error),
                      ),
                    if (getLowStockCount() == 0 && getOutOfStockCount() == 0)
                      _buildInventoryBadge('All Stocked', BloodAppTheme.success),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
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
            icon: Icons.bloodtype,
            title: 'Blood Requests',
            subtitle: _incomingRequestsCount > 0 
                ? '$_incomingRequestsCount pending requests'
                : 'View and manage requests',
            iconColor: BloodAppTheme.accent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BloodBankRequestsScreen()),
            ),
            badge: _incomingRequestsCount,
          ),
          Divider(height: 1, indent: 70, endIndent: 16, color: Colors.grey.shade200),
          _buildQuickActionTile(
            icon: Icons.inventory,
            title: 'Manage Inventory',
            subtitle: 'Update blood stock levels',
            iconColor: BloodAppTheme.primary,
            onTap: () => Navigator.pushNamed(context, '/blood_bank_inventory')
                .then((_) => fetchProfileStatus()),
          ),
          Divider(height: 1, indent: 70, endIndent: 16, color: Colors.grey.shade200),
          _buildQuickActionTile(
            icon: Icons.person,
            title: 'Profile Settings',
            subtitle: 'Update blood bank information',
            iconColor: BloodAppTheme.info,
            onTap: () => Navigator.pushNamed(context, '/blood_bank_profile_completion')
                .then((_) => fetchProfileStatus()),
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
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
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
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: BloodAppTheme.textPrimary,
                      ),
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
              Icon(Icons.chevron_right, color: BloodAppTheme.textHint, size: 22),
            ],
          ),
        ),
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
}
