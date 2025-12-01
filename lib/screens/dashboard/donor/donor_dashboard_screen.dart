import 'dart:ui' show ImageFilter;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../services/donor_service.dart';
import '../../../services/location_service.dart';
import '../../../services/fcm_service.dart';
import '../../../core/notification/dev_inbox_listener.dart';
import '../../../widgets/custom_snackbar.dart';
import '../../../core/theme.dart';
import 'donor_profile_screen.dart';
import 'donor_requests_screen.dart';

class DonorDashboardScreen extends StatefulWidget {
  const DonorDashboardScreen({super.key});

  @override
  State<DonorDashboardScreen> createState() => _DonorDashboardScreenState();
}

class _DonorDashboardScreenState extends State<DonorDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _donorService = DonorService();
  final _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isAvailable = false;
  bool _profileCompleted = false;
  String? _city;
  String? _bloodType;
  String? _donorName;
  bool _navigating = false;
  int _totalDonations = 0;
  int _acceptedRequests = 0;
  bool _hasLocation = false;
  bool _locationPopupShown = false;
  int _incomingRequestsCount = 0;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _loadProfile();
    _loadStats();
    _startRealTimeListeners();
    _initializeNotifications();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLocationAndShowPopup();
    });
  }

  void _startRealTimeListeners() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // Incoming requests listener
    _firestore
        .collection('blood_requests')
        .where('potentialDonors', arrayContains: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        final newCount = snapshot.docs.length;
        if (newCount > _incomingRequestsCount && _isAvailable) {
          _showNewRequestNotification(newCount);
        }
        setState(() {
          _incomingRequestsCount = newCount;
        });
      }
    });

    // Accepted requests listener
    _firestore
        .collection('blood_requests')
        .where('acceptedBy', isEqualTo: userId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _acceptedRequests = snapshot.docs.length;
        });
      }
    });

    // Completed donations listener
    _firestore
        .collection('blood_requests')
        .where('acceptedBy', isEqualTo: userId)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _totalDonations = snapshot.docs.length;
        });
      }
    });
  }

  Future<void> _initializeNotifications() async {
    final user = _auth.currentUser;
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

  void _showNewRequestNotification(int count) {
    if (!mounted) return;

    AppSnackbar.showNotification(
      context,
      title: '🎯 New Blood Request${count > 1 ? 's' : ''}',
      body: '$count request${count > 1 ? 's' : ''} need your help! Tap to view.',
      onTap: _openRequestsScreen,
    );
  }

  Future<void> _checkLocationAndShowPopup() async {
    if (_locationPopupShown) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data();

    bool hasLocation = userData?['location'] != null;

    if (!hasLocation && mounted && !_locationPopupShown) {
      _locationPopupShown = true;
      _showLocationRequiredPopup();
    }
  }

  Future<void> _showLocationRequiredPopup() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => LocationRequiredDialog(
        onUpdateLocation: _updateUserLocation,
      ),
    );
  }

  Future<void> _updateUserLocation() async {
    try {
      Position? position = await LocationService.getCurrentLocation();

      if (position != null) {
        final user = _auth.currentUser;
        if (user != null) {
          await _firestore.collection('users').doc(user.uid).update({
            'location': GeoPoint(position.latitude, position.longitude),
            'locationUpdatedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          setState(() {
            _hasLocation = true;
          });

          if (mounted) {
            AppSnackbar.showSuccess(context, 'Location updated successfully!');
          }
        }
      } else {
        if (mounted) {
          AppSnackbar.showError(
            context,
            'Could not get location',
            subtitle: 'Please enable location services',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Error updating location', subtitle: e.toString());
      }
    }
  }

  Future<void> _loadProfile() async {
    final uid = _auth.currentUser!.uid;
    final doc = await _firestore.collection('users').doc(uid).get();
    final d = doc.data() ?? {};
    if (!mounted) return;
    setState(() {
      _isAvailable = (d['isAvailable'] ?? false) as bool;
      _profileCompleted = (d['profileCompleted'] ?? false) as bool;
      _city = d['city'] as String?;
      _bloodType = (d['bloodGroup'] ?? d['bloodType'] as String?)?.toUpperCase();
      _donorName = d['fullName'] as String?;
      _hasLocation = d['location'] != null;
    });
  }

  Future<void> _loadStats() async {
    final stats = await _donorService.getDonorStats();
    if (mounted) {
      setState(() {
        _totalDonations = stats['totalDonations'] ?? 0;
      });
    }
  }

  Future<void> _toggle(bool v) async {
    if (!_hasLocation) {
      _showLocationRequiredPopup();
      return;
    }

    await _donorService.toggleAvailability(v);
    if (!mounted) return;
    setState(() => _isAvailable = v);

    if (mounted) {
      if (v) {
        AppSnackbar.showSuccess(
          context,
          'You are now available!',
          subtitle: 'You will receive blood request notifications',
        );
      } else {
        AppSnackbar.showWarning(
          context,
          'You are now unavailable',
          subtitle: 'You won\'t receive new requests',
        );
      }
    }
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
    if (!_hasLocation) {
      _showLocationRequiredPopup();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DonorRequestsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = _profileCompleted;
    final canReceive = ready && _isAvailable && _city != null && _bloodType != null && _hasLocation;

    return Scaffold(
      backgroundColor: BloodAppTheme.background,
      body: Stack(
        children: [
          // Background decorative elements
          Positioned(top: -100, right: -80, child: _blob(200, BloodAppTheme.primary.withOpacity(0.1))),
          Positioned(bottom: -60, left: -40, child: _blob(160, BloodAppTheme.accent.withOpacity(0.1))),
          Positioned(top: 200, left: -50, child: _blob(120, BloodAppTheme.success.withOpacity(0.08))),

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
                      icon: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.person, color: Colors.white, size: 22),
                          ),
                          if (_incomingRequestsCount > 0)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: BloodAppTheme.accent,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                child: Text(
                                  _incomingRequestsCount > 9 ? '9+' : _incomingRequestsCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
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
                        // Location Warning
                        if (!_hasLocation) ...[
                          const SizedBox(height: 16),
                          _buildLocationWarningBanner(),
                        ],

                        // Incoming Requests Banner
                        if (_incomingRequestsCount > 0 && _isAvailable) ...[
                          const SizedBox(height: 16),
                          _buildIncomingRequestsBanner(),
                        ],

                        // Real-time Stats
                        const SizedBox(height: 16),
                        _buildRealTimeStats(),

                        // Blood Type & Availability Card
                        const SizedBox(height: 16),
                        _buildBloodTypeAvailabilityCard(),

                        // Quick Actions
                        const SizedBox(height: 24),
                        _buildQuickActionsHeader(),
                        const SizedBox(height: 12),
                        _buildQuickActions(canReceive, ready),

                        // Recent Donations
                        const SizedBox(height: 24),
                        _buildRecentActivityHeader(),
                        const SizedBox(height: 12),
                        _buildRecentDonations(),

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
                  child: const Icon(Icons.volunteer_activism, color: Colors.white, size: 24),
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
                        _donorName?.split(' ').first ?? 'Donor',
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
                color: _isAvailable 
                    ? Colors.white.withOpacity(0.2) 
                    : Colors.orange.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isAvailable ? Icons.check_circle : Icons.pause_circle,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isAvailable ? 'Available ✓' : 'Unavailable',
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

  Widget _buildLocationWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_off, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Location Required',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Update your location to receive blood requests',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _showLocationRequiredPopup,
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Update',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingRequestsBanner() {
    return GestureDetector(
      onTap: _openRequestsScreen,
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
                    'Tap to view and help save lives',
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

  Widget _buildRealTimeStats() {
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
                'Your Statistics',
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
              Expanded(child: _buildStatItem('Donations', _totalDonations, BloodAppTheme.success, Icons.favorite)),
              const SizedBox(width: 10),
              Expanded(child: _buildStatItem('Accepted', _acceptedRequests, BloodAppTheme.info, Icons.handshake)),
              const SizedBox(width: 10),
              Expanded(child: _buildStatItem('New', _incomingRequestsCount, BloodAppTheme.accent, Icons.notifications_active)),
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

  Widget _buildBloodTypeAvailabilityCard() {
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
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: BloodAppTheme.getBloodTypeColor(_bloodType ?? 'O+'),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                _bloodType ?? '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
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
                  'Blood Type',
                  style: TextStyle(
                    color: BloodAppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _bloodType ?? 'Not Set',
                  style: TextStyle(
                    color: BloodAppTheme.getBloodTypeColor(_bloodType ?? 'O+'),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_city != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: BloodAppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _city!,
                          style: TextStyle(
                            color: BloodAppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Available',
                style: TextStyle(
                  color: BloodAppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Transform.scale(
                scale: 0.9,
                child: Switch(
                  value: _isAvailable,
                  onChanged: _toggle,
                  activeColor: BloodAppTheme.success,
                  activeTrackColor: BloodAppTheme.success.withOpacity(0.3),
                ),
              ),
            ],
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

  Widget _buildQuickActions(bool canReceive, bool ready) {
    return Column(
      children: [
        // Main action cards in a cleaner grid
        Container(
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
                    ? '$_incomingRequestsCount new requests waiting'
                    : 'View & accept blood requests',
                iconColor: BloodAppTheme.accent,
                enabled: canReceive,
                onTap: _openRequestsScreen,
                badge: _incomingRequestsCount,
                showArrow: true,
              ),
              Divider(height: 1, indent: 70, endIndent: 16, color: Colors.grey.shade200),
              _buildQuickActionTile(
                icon: Icons.person,
                title: 'My Profile',
                subtitle: ready ? 'View & edit your profile' : 'Complete your profile',
                iconColor: BloodAppTheme.primary,
                enabled: true,
                onTap: ready ? _openProfile : _openProfileCompletion,
                showArrow: true,
                showWarning: !ready,
              ),
            ],
          ),
        ),
        
        if (!ready)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [BloodAppTheme.warning.withOpacity(0.15), BloodAppTheme.warning.withOpacity(0.05)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: BloodAppTheme.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: BloodAppTheme.warning.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.warning_amber, color: BloodAppTheme.warning, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Profile Incomplete',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: BloodAppTheme.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Complete to receive blood requests',
                          style: TextStyle(
                            color: BloodAppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _openProfileCompletion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BloodAppTheme.warning,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Complete', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
      ],
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
          'Recent Donations',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: BloodAppTheme.textPrimary,
          ),
        ),
        TextButton(
          onPressed: _openRequestsScreen,
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

  Widget _buildRecentDonations() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return _buildEmptyState();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('blood_requests')
          .where('acceptedBy', isEqualTo: uid)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final completedAt = data['completedAt'] as Timestamp?;
            final bloodType = data['bloodType'] as String? ?? 'Unknown';
            final hospital = data['hospital'] as String? ?? data['city'] as String? ?? 'N/A';
            final units = data['units'] ?? 1;

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
                          hospital,
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
                          completedAt != null
                              ? '${_formatDate(completedAt.toDate())} • $units unit(s)'
                              : '$units unit(s)',
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
                      color: BloodAppTheme.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: BloodAppTheme.success),
                        const SizedBox(width: 4),
                        const Text(
                          'DONE',
                          style: TextStyle(
                            color: BloodAppTheme.success,
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
          }).toList(),
        );
      },
    );
  }

  Widget _buildEmptyState() {
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
            Icons.volunteer_activism,
            size: 48,
            color: BloodAppTheme.textSecondary.withOpacity(0.3),
          ),
          const SizedBox(height: 12),
          const Text(
            'No Donations Yet',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: BloodAppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your donation history will appear here',
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

// ═══════════════════════════════════════════════════════════════
// 📍 LOCATION REQUIRED DIALOG
// ═══════════════════════════════════════════════════════════════

class LocationRequiredDialog extends StatelessWidget {
  final VoidCallback onUpdateLocation;

  const LocationRequiredDialog({super.key, required this.onUpdateLocation});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: BloodAppTheme.warning.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on,
                size: 40,
                color: BloodAppTheme.warning,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Location Required',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: BloodAppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'To help you receive nearby blood requests and save lives, we need your current location.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: BloodAppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: BloodAppTheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Why we need your location?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: BloodAppTheme.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Match you with blood requests in your area\n'
                    '• Help patients find donors nearby\n'
                    '• Make the donation process faster\n'
                    '• Save more lives efficiently',
                    style: TextStyle(
                      color: BloodAppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: BloodAppTheme.textSecondary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Later',
                      style: TextStyle(
                        color: BloodAppTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onUpdateLocation();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BloodAppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Update Now',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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
}
