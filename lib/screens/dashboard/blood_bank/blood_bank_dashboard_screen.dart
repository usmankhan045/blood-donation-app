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
  Map<String, dynamic>? bloodBankData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchProfileStatus();
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
      print('Error fetching profile: $e');
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
        if (units > 0 && units < 5) {
          count++;
        }
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
        if (units == 0) {
          count++;
        }
      }
    });

    return count;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFFF6F9FB),
        appBar: AppBar(
          title: Text('Blood Bank Dashboard'),
          backgroundColor: Color(0xFF67D5B5),
        ),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF67D5B5))),
      );
    }

    // If profile not completed, show completion prompt
    if (profileCompleted == false) {
      return Scaffold(
        backgroundColor: Color(0xFFF6F9FB),
        appBar: AppBar(
          title: Text('Blood Bank Dashboard'),
          backgroundColor: Color(0xFF67D5B5),
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 100,
                  color: Color(0xFF67D5B5),
                ),
                SizedBox(height: 24),
                Text(
                  'Complete Your Profile',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Please complete your blood bank profile to access all features and start managing your inventory.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 32),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF67D5B5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  icon: Icon(Icons.edit, size: 24, color: Colors.white),
                  label: Text(
                    'Complete Profile Now',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
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
      );
    }

    // Main Dashboard
    return Scaffold(
      backgroundColor: Color(0xFFF6F9FB),
      appBar: AppBar(
        title: Text(
          'Blood Bank Dashboard',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Color(0xFF67D5B5),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchProfileStatus,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: fetchProfileStatus,
        color: Color(0xFF67D5B5),
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF67D5B5), Color(0xFF4AB9C5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF67D5B5).withOpacity(0.3),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.bloodtype,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome Back!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            bloodBankData?['bloodBankName'] ?? 'Blood Bank',
                            style: TextStyle(
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
              ),
              SizedBox(height: 24),

              // Analytics Section
              Text(
                'Quick Stats',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 12),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _buildStatCard(
                    icon: Icons.inventory_2_outlined,
                    title: 'Total Units',
                    value: getTotalUnits().toString(),
                    color: Colors.blue,
                  ),
                  _buildStatCard(
                    icon: Icons.water_drop,
                    title: 'Blood Types',
                    value: (bloodBankData?['availableBloodTypes']?.length ?? 0).toString(),
                    color: Colors.red,
                  ),
                  _buildStatCard(
                    icon: Icons.warning_amber_outlined,
                    title: 'Low Stock',
                    value: getLowStockCount().toString(),
                    color: Colors.orange,
                  ),
                  _buildStatCard(
                    icon: Icons.block,
                    title: 'Out of Stock',
                    value: getOutOfStockCount().toString(),
                    color: Colors.grey,
                  ),
                ],
              ),
              SizedBox(height: 24),

              // Features Section
              Text(
                'Manage',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 12),

              _buildFeatureCard(
                icon: Icons.inventory,
                title: 'Inventory Management',
                subtitle: 'Manage blood stock and units',
                color: Color(0xFF67D5B5),
                onTap: () {
                  Navigator.pushNamed(context, '/blood_bank_inventory')
                      .then((_) => fetchProfileStatus());
                },
              ),
              SizedBox(height: 12),

              _buildFeatureCard(
                icon: Icons.request_page,
                title: 'Blood Requests',
                subtitle: 'View and manage requests',
                color: Colors.blue,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Requests feature coming soon')),
                  );
                },
              ),
              SizedBox(height: 12),

              _buildFeatureCard(
                icon: Icons.person,
                title: 'Profile Settings',
                subtitle: 'Update blood bank information',
                color: Colors.purple,
                onTap: () {
                  Navigator.pushNamed(context, '/blood_bank_profile_completion')
                      .then((_) => fetchProfileStatus());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}