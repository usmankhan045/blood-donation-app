import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminManageUsersScreen extends StatefulWidget {
  const AdminManageUsersScreen({Key? key}) : super(key: key);

  @override
  _AdminManageUsersScreenState createState() => _AdminManageUsersScreenState();
}

class _AdminManageUsersScreenState extends State<AdminManageUsersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _selectedRole = 'all';
  String _searchQuery = '';

  final List<String> _roles = [
    'all',
    'donor',
    'recipient',
    'hospital',
    'blood_bank',
    'admin'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Manage Users',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search users by name or email...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _roles.map((role) {
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            role == 'all' ? 'All' : _formatRole(role),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _selectedRole == role
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                          selected: _selectedRole == role,
                          onSelected: (selected) {
                            setState(() {
                              _selectedRole = selected ? role : 'all';
                            });
                          },
                          backgroundColor: Colors.grey[100],
                          selectedColor: const Color(0xFF667eea),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildUsersList(),
          ),
        ],
      ),
    );
  }

  String _formatRole(String role) {
    switch (role) {
      case 'donor': return 'Donors';
      case 'recipient': return 'Recipients';
      case 'hospital': return 'Hospitals';
      case 'blood_bank': return 'Blood Banks';
      case 'admin': return 'Admins';
      default: return role;
    }
  }

  Widget _buildUsersList() {
    CollectionReference collection = _firestore.collection('users');
    Query query = collection;

    // Apply role filter
    if (_selectedRole != 'all') {
      query = query.where('role', isEqualTo: _selectedRole);
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      query = query
          .where('name', isGreaterThanOrEqualTo: _searchQuery)
          .where('name', isLessThanOrEqualTo: '$_searchQuery\uf8ff');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No users found',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Try changing your search or filters',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final user = snapshot.data!.docs[index];
            return _buildUserCard(user);
          },
        );
      },
    );
  }

  Widget _buildUserCard(DocumentSnapshot user) {
    final data = user.data() as Map<String, dynamic>;
    final role = data['role'] ?? 'user';
    final isVerified = data['isVerified'] ?? false;
    final isActive = data['isActive'] ?? true;

    // Get user name - use email username if name is not available
    final userName = data['name']?.toString().isNotEmpty == true
        ? data['name']
        : data['email']?.split('@').first ?? 'User';

    Color roleColor;
    IconData roleIcon;
    String roleLabel;

    switch (role) {
      case 'donor':
        roleColor = Color(0xFFE53E3E);
        roleIcon = Icons.favorite;
        roleLabel = 'DONOR';
        break;
      case 'recipient':
        roleColor = Color(0xFF3182CE);
        roleIcon = Icons.person;
        roleLabel = 'RECIPIENT';
        break;
      case 'hospital':
        roleColor = Color(0xFF38A169);
        roleIcon = Icons.local_hospital;
        roleLabel = 'HOSPITAL';
        break;
      case 'blood_bank':
        roleColor = Color(0xFF319795);
        roleIcon = Icons.business;
        roleLabel = 'BLOOD BANK';
        break;
      case 'admin':
        roleColor = Color(0xFF805AD5);
        roleIcon = Icons.admin_panel_settings;
        roleLabel = 'ADMIN';
        break;
      default:
        roleColor = Colors.grey;
        roleIcon = Icons.person;
        roleLabel = 'USER';
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        roleColor.withOpacity(0.2),
                        roleColor.withOpacity(0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(roleIcon, color: roleColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['email'] ?? 'No email',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        roleLabel,
                        style: TextStyle(
                          color: roleColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            color: isActive ? Colors.green : Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatusChip(
                  isVerified ? 'Verified' : 'Not Verified',
                  isVerified ? Colors.green : Colors.orange,
                ),
                if (data['bloodType'] != null && data['bloodType'].toString().isNotEmpty)
                  _buildStatusChip(
                    data['bloodType'],
                    Colors.blue,
                  ),
                if (data['phone'] != null && data['phone'].toString().isNotEmpty)
                  _buildStatusChip(
                    'Phone Verified',
                    Colors.teal,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _toggleUserStatus(user.id, !isActive),
                    icon: Icon(
                      isActive ? Icons.block : Icons.check_circle,
                      size: 18,
                    ),
                    label: Text(isActive ? 'Deactivate' : 'Activate'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isActive ? Colors.red : Colors.green,
                      side: BorderSide(
                        color: isActive ? Colors.red : Colors.green,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showUserDetails(user, userName),
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('Details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _toggleUserStatus(String userId, bool newStatus) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isActive': newStatus,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'User ${newStatus ? 'activated' : 'deactivated'} successfully',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          backgroundColor: newStatus ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Failed to update user status',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showUserDetails(DocumentSnapshot user, String userName) {
    final data = user.data() as Map<String, dynamic>;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'User Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              _buildDetailRow('Name', userName),
              _buildDetailRow('Email', data['email'] ?? 'N/A'),
              _buildDetailRow('Role', data['role']?.toString().toUpperCase() ?? 'N/A'),
              _buildDetailRow('Phone', data['phone'] ?? 'N/A'),
              if (data['bloodType'] != null && data['bloodType'].toString().isNotEmpty)
                _buildDetailRow('Blood Type', data['bloodType']),
              _buildDetailRow(
                'Verified',
                (data['isVerified'] ?? false) ? 'Yes' : 'No',
              ),
              _buildDetailRow(
                'Active',
                (data['isActive'] ?? true) ? 'Yes' : 'No',
              ),
              if (data['createdAt'] != null)
                _buildDetailRow(
                  'Joined',
                  _formatTimestamp(data['createdAt']),
                ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'Unknown';
  }
}