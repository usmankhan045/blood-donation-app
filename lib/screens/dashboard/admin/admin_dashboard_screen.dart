import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_reports_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_verify_users_screen.dart';
import 'admin_manage_users_screen.dart';
import 'admin_manage_admins_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _totalUsers = 0;
  int _totalRequests = 0;
  int _completedDonations = 0;
  int _activeDonors = 0;
  int _pendingVerifications = 0;
  bool _isLoading = true;
  bool _isSuperAdmin = false;
  String _adminName = 'Admin';

  @override
  void initState() {
    super.initState();
    print('=== INIT STATE CALLED ===');
    _loadDashboardStats();
    _checkSuperAdminStatus();
  }

  Future<void> _checkSuperAdminStatus() async {
    final user = _auth.currentUser;
    print('=== CHECKING SUPER ADMIN STATUS ===');
    print('Current User UID: ${user?.uid}');
    print('Current User Email: ${user?.email}');

    if (user != null) {
      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        print('User Document Exists: ${userDoc.exists}');

        if (userDoc.exists) {
          final data = userDoc.data();
          print('User Data: $data');

          final isSuperAdmin = data?['isSuperAdmin'] ?? false;
          final name = data?['name'] ?? 'Admin';

          print('isSuperAdmin value: $isSuperAdmin');
          print('User Name: $name');

          setState(() {
            _isSuperAdmin = isSuperAdmin;
            _adminName = name;
          });

          print('=== SUPER ADMIN STATUS UPDATED ===');
          print('_isSuperAdmin: $_isSuperAdmin');
          print('_adminName: $_adminName');
        } else {
          print('User document does not exist in Firestore');
        }
      } catch (e) {
        print('Error checking super admin status: $e');
      }
    } else {
      print('No user is logged in');
    }
  }

  Future<void> _loadDashboardStats() async {
    setState(() {
      _isLoading = true;
    });

    await Future.wait([
      _loadUserStats(),
      _loadRequestStats(),
      _loadPendingVerifications(),
    ]);

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadUserStats() async {
    final usersSnapshot = await _firestore.collection('users').get();
    final donorsSnapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'donor')
        .where('isAvailable', isEqualTo: true)
        .get();

    setState(() {
      _totalUsers = usersSnapshot.docs.length;
      _activeDonors = donorsSnapshot.docs.length;
    });
  }

  Future<void> _loadRequestStats() async {
    final requestsSnapshot = await _firestore.collection('blood_requests').get();
    final completedSnapshot = await _firestore
        .collection('blood_requests')
        .where('status', isEqualTo: 'completed')
        .get();

    setState(() {
      _totalRequests = requestsSnapshot.docs.length;
      _completedDonations = completedSnapshot.docs.length;
    });
  }

  Future<void> _loadPendingVerifications() async {
    final hospitalsSnapshot = await _firestore
        .collection('hospitals')
        .where('isVerified', isEqualTo: false)
        .get();

    final bloodBanksSnapshot = await _firestore
        .collection('blood_banks')
        .where('isVerified', isEqualTo: false)
        .get();

    setState(() {
      _pendingVerifications = hospitalsSnapshot.docs.length + bloodBanksSnapshot.docs.length;
    });
  }

  Widget _buildDashboardItem(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.15),
                color.withOpacity(0.05),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String label, int count, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate total modules based on user role
    final totalModules = _isSuperAdmin ? 4 : 3;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          // Debug button to check Super Admin status
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              print('=== MANUAL SUPER ADMIN CHECK ===');
              print('_isSuperAdmin: $_isSuperAdmin');
              print('_adminName: $_adminName');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isSuperAdmin
                      ? 'Super Admin: ACTIVE'
                      : 'Super Admin: INACTIVE'
                  ),
                  backgroundColor: _isSuperAdmin ? Colors.green : Colors.orange,
                ),
              );
            },
          ),
          if (_isSuperAdmin)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.star, color: Colors.purple, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Super Admin',
                    style: TextStyle(
                      color: Colors.purple,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.blue),
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/admin_profile');
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardStats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isSuperAdmin ? Icons.star : Icons.admin_panel_settings,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, $_adminName',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isSuperAdmin
                                ? 'Super Admin - Full System Access'
                                : 'System Overview & Management',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _isSuperAdmin ? 'Super Admin Access' : 'Admin Access',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Quick Stats Row
              Row(
                children: [
                  const Text(
                    'Management Tools',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$totalModules Modules',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Dashboard Grid - Removed Blood Requests, Hospitals, Blood Banks
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
                children: [
                  _buildDashboardItem(
                    context,
                    'Analytics & Reports',
                    'View system statistics and reports',
                    Icons.analytics,
                    const Color(0xFF667eea),
                        () {
                      Navigator.pushNamed(context, '/admin_reports');
                    },
                  ),
                  _buildDashboardItem(
                    context,
                    'Verify Institutions',
                    'Approve hospitals & blood banks',
                    Icons.verified_user,
                    const Color(0xFF4CAF50),
                        () {
                      Navigator.pushNamed(context, '/admin_verify_users');
                    },
                  ),
                  _buildDashboardItem(
                    context,
                    'Manage Users',
                    'View and manage all users',
                    Icons.people_alt,
                    const Color(0xFFFF9800),
                        () {
                      Navigator.pushNamed(context, '/admin_manage_users');
                    },
                  ),
                  // Super Admin Only - Manage Admins
                  if (_isSuperAdmin)
                    _buildDashboardItem(
                      context,
                      'Manage Admins',
                      'Add or remove administrators',
                      Icons.admin_panel_settings,
                      const Color(0xFF9C27B0),
                          () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminManageAdminsScreen(),
                          ),
                        );
                      },
                    ),
                ],
              ),

              const SizedBox(height: 30),

              // System Status Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live System Status',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildStatusIndicator('Active Users', _totalUsers, Colors.green),
                        _buildStatusIndicator('Pending Verifications', _pendingVerifications, Colors.orange),
                        _buildStatusIndicator('Active Requests', _totalRequests, Colors.blue),
                        _buildStatusIndicator('Active Donors', _activeDonors, Colors.pink),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.build, color: Colors.blue),
            SizedBox(width: 8),
            Text('Coming Soon'),
          ],
        ),
        content: const Text('This feature is under development and will be available in the next update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}