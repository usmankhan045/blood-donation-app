import 'dart:ui' show ImageFilter;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../services/donor_service.dart';
import '../../../services/location_service.dart'; // ADD THIS IMPORT
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isAvailable = false;
  bool _profileCompleted = false;
  String? _city;
  String? _bloodType;
  String? _donorName;
  bool _navigating = false;
  int _totalDonations = 0;
  int _pendingRequests = 0;
  bool _hasLocation = false; // ADD THIS
  bool _locationPopupShown = false; // ADD THIS
  int _incomingRequestsCount = 0; // ADD THIS: Track incoming requests

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadStats();
    _startIncomingRequestsListener(); // ADD THIS: Listen for incoming requests
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLocationAndShowPopup(); // ADD THIS
    });
  }

  // ADD THIS METHOD: Listen for incoming blood requests
  void _startIncomingRequestsListener() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _firestore
        .collection('blood_requests')
        .where('potentialDonors', arrayContains: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _incomingRequestsCount = snapshot.docs.length;
        });
        print('📬 Incoming requests count updated: $_incomingRequestsCount');

        // Show notification if new requests come in
        if (snapshot.docs.isNotEmpty && _isAvailable) {
          _showNewRequestNotification(snapshot.docs.length);
        }
      }
    });
  }

  // ADD THIS METHOD: Show notification for new requests
  void _showNewRequestNotification(int count) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎯 $count new blood request${count > 1 ? 's' : ''} need your help!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: _openRequestsScreen,
        ),
      ),
    );
  }

  // ADD THIS METHOD: Check location and show popup if missing
  Future<void> _checkLocationAndShowPopup() async {
    if (_locationPopupShown) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userDoc.data();

    bool hasLocation = userData?['location'] != null;

    if (!hasLocation && mounted && !_locationPopupShown) {
      _locationPopupShown = true;
      _showLocationRequiredPopup();
    }
  }

  // ADD THIS METHOD: Show location required popup
  Future<void> _showLocationRequiredPopup() async {
    await showDialog(
      context: context,
      barrierDismissible: false, // User must take action
      builder: (context) => LocationRequiredDialog(
        onUpdateLocation: _updateUserLocation,
      ),
    );
  }

  // ADD THIS METHOD: Update user location
  Future<void> _updateUserLocation() async {
    try {
      Position? position = await LocationService.getCurrentLocation();

      if (position != null) {
        final user = _auth.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'location': GeoPoint(position.latitude, position.longitude),
            'locationUpdatedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Update local state
          setState(() {
            _hasLocation = true;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Location updated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Could not get location. Please enable location services.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error updating location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
      _hasLocation = d['location'] != null; // ADD THIS
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
    if (!_hasLocation) { // ADD THIS CHECK
      _showLocationRequiredPopup();
      return;
    }

    await _donorService.toggleAvailability(v);
    if (!mounted) return;
    setState(() => _isAvailable = v);

    // Show status message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(v ? '✅ You are now available to receive requests' : '🔕 You are now unavailable'),
          backgroundColor: v ? Colors.green : Colors.orange,
        ),
      );
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
    if (!_hasLocation) { // ADD THIS CHECK
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
    final canReceive = ready && _isAvailable && _city != null && _bloodType != null && _hasLocation; // ADD _hasLocation

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FB),
      appBar: AppBar(
        elevation: 0,
        title: const Text('Donor Dashboard'),
        centerTitle: true,
        backgroundColor: const Color(0xFF67D5B5),
        foregroundColor: Colors.white,
        actions: [
          // ADD INCOMING REQUEST BADGE
          Stack(
            children: [
              IconButton(
                tooltip: 'My Profile',
                icon: const Icon(Icons.account_circle),
                onPressed: _openProfile,
              ),
              if (_incomingRequestsCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _incomingRequestsCount > 9 ? '9+' : _incomingRequestsCount.toString(),
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
        ],
      ),
      body: Stack(
        children: [
          // Background decorative elements
          Positioned(top: -80, left: -60, child: _blob(160, const Color(0x1567D5B5))),
          Positioned(bottom: -70, right: -50, child: _blob(140, const Color(0x154AB9C5))),
          Positioned(top: 100, right: -30, child: _blob(80, const Color(0x15FF6B6B))),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Header
                  _buildWelcomeHeader(),
                  const SizedBox(height: 20),

                  // ADD LOCATION WARNING BANNER
                  if (!_hasLocation) _buildLocationWarningBanner(),
                  if (!_hasLocation) const SizedBox(height: 12),

                  // ADD INCOMING REQUESTS BANNER
                  if (_incomingRequestsCount > 0 && _isAvailable) _buildIncomingRequestsBanner(),
                  if (_incomingRequestsCount > 0 && _isAvailable) const SizedBox(height: 12),

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
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ADD THIS WIDGET: Incoming requests banner
  Widget _buildIncomingRequestsBanner() {
    return GestureDetector(
      onTap: _openRequestsScreen,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bloodtype, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_incomingRequestsCount New Request${_incomingRequestsCount > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tap to view and help save lives',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  // ADD THIS WIDGET: Location warning banner
  Widget _buildLocationWarningBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.location_off, color: Colors.orange[800], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location Required',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Update your location to receive blood requests',
                  style: TextStyle(
                    color: Colors.orange[700],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _showLocationRequiredPopup,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
            ),
            child: Text(
              'Update',
              style: TextStyle(
                color: Colors.orange[800],
                fontSize: 12,
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
            icon: Icons.bloodtype_outlined,
            value: _incomingRequestsCount.toString(), // UPDATED: Show incoming requests
            label: 'New Requests',
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
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Icon(
              _isAvailable ? Icons.volunteer_activism : Icons.volunteer_activism_outlined,
              color: Colors.white,
              size: 24,
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
                    fontSize: 16,
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
                    fontSize: 12,
                  ),
                ),
                // ADD INCOMING REQUEST INFO
                if (_isAvailable && _incomingRequestsCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$_incomingRequestsCount request${_incomingRequestsCount > 1 ? 's' : ''} waiting',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Transform.scale(
            scale: 1.1,
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
                badgeCount: _incomingRequestsCount, // ADD BADGE COUNT
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
                  if (!_hasLocation) { // ADD THIS CHECK
                    _showLocationRequiredPopup();
                    return;
                  }
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[100]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.orange[800], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Complete Your Profile',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Finish your profile to start receiving requests',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _openProfileCompletion,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                  ),
                  child: Text(
                    'Complete',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontSize: 12,
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
            if (!_hasLocation) { // ADD THIS CHECK
              _showLocationRequiredPopup();
              return;
            }
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
      height: 200,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
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
                margin: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  elevation: 1,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF67D5B5).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.bloodtype,
                        color: const Color(0xFF67D5B5),
                        size: 18,
                      ),
                    ),
                    title: Text(
                      hospital,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
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
                        fontSize: 11,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        bloodType,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
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
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bloodtype_outlined,
              size: 40,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 8),
            Text(
              'No Donations Yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your donation history will appear here',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
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

// ADD THIS DIALOG CLASS
class LocationRequiredDialog extends StatelessWidget {
  final VoidCallback onUpdateLocation;

  const LocationRequiredDialog({super.key, required this.onUpdateLocation});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.orange[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_on,
                size: 40,
                color: Colors.orange[800],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Location Required',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'To help you receive nearby blood requests and save lives, we need your current location.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Why we need your location?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Match you with blood requests in your area\n'
                  '• Help patients find donors nearby\n'
                  '• Make the donation process faster\n'
                  '• Save more lives efficiently',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Later',
                      style: TextStyle(
                        color: Colors.grey,
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
                      backgroundColor: Colors.orange[800],
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
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
  final int badgeCount; // ADD BADGE COUNT

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    required this.enabled,
    this.badgeCount = 0, // DEFAULT TO 0
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Material(
          color: enabled ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
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
                    size: 20,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: enabled ? color : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: enabled ? color.withOpacity(0.7) : Colors.grey,
                      fontSize: 10,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
        // ADD BADGE
        if (badgeCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                badgeCount > 9 ? '9+' : badgeCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}