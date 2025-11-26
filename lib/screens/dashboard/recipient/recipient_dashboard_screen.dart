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
  String? _userName;
  int _activeRequests = 0;
  int _completedRequests = 0;
  String? _bloodType;

  @override
  void initState() {
    super.initState();
    fetchProfileStatus();
    _loadUserData();
    _loadRequestStats();
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
        print('Error loading user data: $e');
      }
    }
  }

  Future<void> _loadRequestStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final activeSnapshot = await FirebaseFirestore.instance
            .collection('requests')
            .where('requesterId', isEqualTo: user.uid)
            .where('status', whereIn: ['active', 'accepted'])
            .get();

        final completedSnapshot = await FirebaseFirestore.instance
            .collection('requests')
            .where('requesterId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'completed')
            .get();

        if (mounted) {
          setState(() {
            _activeRequests = activeSnapshot.docs.length;
            _completedRequests = completedSnapshot.docs.length;
          });
        }
      } catch (e) {
        print('Error loading request stats: $e');
      }
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

  void _openProfileCompletion() async {
    await Navigator.pushNamed(context, '/recipient_profile_completion');
    fetchProfileStatus();
    _loadRequestStats();
  }

  void _openProfile() {
    Navigator.pushNamed(context, '/recipient/profile');
  }

  @override
  Widget build(BuildContext context) {
    if (profileCompleted == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading...'),
            ],
          ),
        ),
      );
    }

    final canUseFeatures = profileCompleted ?? false;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Recipient Dashboard'),
        backgroundColor: Color(0xFF67D5B5),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.person),
            onPressed: _openProfile,
          ),
        ],
      ),
      floatingActionButton: canUseFeatures ? FloatingActionButton(
        onPressed: _openRequestBlood,
        backgroundColor: Color(0xFF67D5B5),
        child: Icon(Icons.add, color: Colors.white),
      ) : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // Welcome Section
              _buildWelcomeSection(),
              SizedBox(height: 24),

              // Profile Status
              _buildProfileStatusCard(canUseFeatures),
              SizedBox(height: 24),

              // Stats Section
              if (canUseFeatures) _buildStatsSection(),
              if (canUseFeatures) SizedBox(height: 24),

              // Quick Actions
              _buildQuickActions(canUseFeatures),
              SizedBox(height: 24),

              // Profile Reminder
              if (!canUseFeatures) _buildProfileReminder(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF67D5B5), Color(0xFF4AB9C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back,',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            _userName?.split(' ').first ?? 'Recipient',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Ready to request blood?',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStatusCard(bool canUseFeatures) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            canUseFeatures ? Icons.verified : Icons.info,
            color: canUseFeatures ? Colors.green : Colors.orange,
            size: 40,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  canUseFeatures ? 'Profile Complete' : 'Complete Profile',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  canUseFeatures
                      ? 'You can access all features'
                      : 'Finish setup to request blood',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (!canUseFeatures)
            IconButton(
              onPressed: _openProfileCompletion,
              icon: Icon(Icons.arrow_forward, color: Color(0xFF67D5B5)),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Requests',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatItem(
                value: _activeRequests.toString(),
                label: 'Active',
                color: Color(0xFFFFA726),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _StatItem(
                value: _completedRequests.toString(),
                label: 'Completed',
                color: Color(0xFF4CAF50),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _StatItem(
                value: (_activeRequests + _completedRequests).toString(),
                label: 'Total',
                color: Color(0xFF67D5B5),
              ),
            ),
          ],
        ),
        if (_bloodType != null) ...[
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red[100]!),
            ),
            child: Row(
              children: [
                Icon(Icons.bloodtype, color: Colors.red, size: 24),
                SizedBox(width: 12),
                Text(
                  'Blood Type: ',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  _bloodType!,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickActions(bool canUseFeatures) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            _ActionCard(
              title: 'Request Blood',
              icon: Icons.bloodtype,
              color: Color(0xFF67D5B5),
              enabled: canUseFeatures,
              onTap: _openRequestBlood,
            ),
            _ActionCard(
              title: 'My Requests',
              icon: Icons.history,
              color: Color(0xFFFFA726),
              enabled: canUseFeatures,
              onTap: _openMyRequests,
            ),
            _ActionCard(
              title: 'Alerts',
              icon: Icons.notifications,
              color: Color(0xFFEF5350),
              enabled: canUseFeatures,
              onTap: _openAlerts,
            ),
            _ActionCard(
              title: 'Profile',
              icon: Icons.person,
              color: Color(0xFF9575CD),
              enabled: true,
              onTap: _openProfile,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileReminder() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[100]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: Colors.orange[800]),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Complete your profile to request blood',
              style: TextStyle(color: Colors.orange[800]),
            ),
          ),
          TextButton(
            onPressed: _openProfileCompletion,
            child: Text('Complete'),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: enabled ? color : Colors.grey,
                size: 32,
              ),
              SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: enabled ? Colors.black87 : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}