import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 👑 SUPER ADMIN ONLY SCREEN
/// Manages administrators - only super admin can access this
/// Super admin cannot be deleted by anyone
class AdminManageAdminsScreen extends StatefulWidget {
  const AdminManageAdminsScreen({Key? key}) : super(key: key);

  @override
  _AdminManageAdminsScreenState createState() => _AdminManageAdminsScreenState();
}

class _AdminManageAdminsScreenState extends State<AdminManageAdminsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  List<Map<String, dynamic>> _admins = [];
  bool _isLoading = true;
  bool _isAddingAdmin = false;
  bool _isSuperAdmin = false;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid ?? '';
    _checkSuperAdminAndLoadAdmins();
  }

  Future<void> _checkSuperAdminAndLoadAdmins() async {
    try {
      // First check if current user is super admin
      final currentUserDoc = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .get();

      if (!currentUserDoc.exists) {
        _showError('User not found');
        Navigator.pop(context);
        return;
      }

      final currentUserData = currentUserDoc.data()!;
      _isSuperAdmin = currentUserData['isSuperAdmin'] ?? false;

      if (!_isSuperAdmin) {
        _showError('Only Super Admin can access this screen');
        Navigator.pop(context);
        return;
      }

      await _loadAdmins();
    } catch (e) {
      print('Error checking super admin: $e');
      _showError('Error loading admin data');
      Navigator.pop(context);
    }
  }

  Future<void> _loadAdmins() async {
    setState(() => _isLoading = true);

    try {
      // Query all users with role 'admin'
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      setState(() {
        _admins = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? data['fullName'] ?? '',
            'email': data['email'] ?? '',
            'role': data['role'] ?? 'admin',
            'isSuperAdmin': data['isSuperAdmin'] ?? false,
            'createdAt': data['createdAt'],
            'isActive': data['isActive'] ?? true,
            'adminLevel': data['adminLevel'] ?? 'Admin',
          };
        }).toList();

        // Sort: Super Admin first, then by name
        _admins.sort((a, b) {
          if (a['isSuperAdmin'] && !b['isSuperAdmin']) return -1;
          if (!a['isSuperAdmin'] && b['isSuperAdmin']) return 1;
          return (a['name'] as String).compareTo(b['name'] as String);
        });

        _isLoading = false;
      });
    } catch (e) {
      print('Error loading admins: $e');
      setState(() => _isLoading = false);
      _showError('Error loading admins');
    }
  }

  Future<void> _createAdmin() async {
    if (_emailController.text.isEmpty ||
        _nameController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      _showError('Please fill all fields');
      return;
    }

    if (_passwordController.text.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    setState(() => _isAddingAdmin = true);

    try {
      // 🔧 IMPORTANT: Use Firebase Admin SDK or Cloud Functions for creating users
      // This is a workaround - in production, use Cloud Functions to create admin users
      // Note: This will log out the current admin as Firebase Auth only allows one user at a time
      
      // Create the new admin user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Save user data to Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': _emailController.text.trim(),
        'name': _nameController.text.trim(),
        'role': 'admin',
        'isSuperAdmin': false, // New admins are NOT super admins
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'adminLevel': 'Admin',
        'createdBy': _currentUserId,
        'profileCompleted': false,
      });

      // Clear form
      _emailController.clear();
      _nameController.clear();
      _passwordController.clear();

      // Sign out the newly created user and sign back in as original admin
      // NOTE: This is a workaround - in production use Cloud Functions
      await _auth.signOut();
      
      // Show success message
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Admin created! Please log in again.'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate to login
        Navigator.pushNamedAndRemoveUntil(context, '/admin_login', (route) => false);
      }
    } catch (e) {
      setState(() => _isAddingAdmin = false);
      String errorMessage = 'Error creating admin';
      if (e is FirebaseAuthException) {
        if (e.code == 'email-already-in-use') {
          errorMessage = 'Email is already registered';
        } else if (e.code == 'weak-password') {
          errorMessage = 'Password is too weak';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'Invalid email address';
        }
      }
      _showError(errorMessage);
    }
  }

  Future<void> _toggleAdminStatus(String adminId, bool currentStatus, bool isAdminSuperAdmin) async {
    // Cannot deactivate super admin
    if (isAdminSuperAdmin) {
      _showError('Cannot deactivate Super Admin');
      return;
    }

    try {
      await _firestore.collection('users').doc(adminId).update({
        'isActive': !currentStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _currentUserId,
      });

      await _loadAdmins();
      _showSuccess('Admin status updated!');
    } catch (e) {
      _showError('Error updating admin status');
    }
  }

  Future<void> _deleteAdmin(String adminId, bool isAdminSuperAdmin, String adminName) async {
    // 👑 SUPER ADMIN PROTECTION: Cannot delete super admin
    if (isAdminSuperAdmin) {
      _showError('Super Admin cannot be deleted!');
      return;
    }

    // Cannot delete yourself
    if (adminId == _currentUserId) {
      _showError('You cannot delete yourself');
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Delete Admin'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "$adminName"?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. The admin will lose all access.',
                      style: TextStyle(fontSize: 12, color: Colors.red),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        // Mark as deleted instead of actually deleting (soft delete)
        await _firestore.collection('users').doc(adminId).update({
          'isActive': false,
          'isDeleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
          'deletedBy': _currentUserId,
        });
        
        await _loadAdmins();
        _showSuccess('Admin deleted successfully!');
      } catch (e) {
        _showError('Error deleting admin');
      }
    }
  }

  void _showAddAdminDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_add, color: Colors.purple),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Add New Admin'),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Note: You will be logged out after creating a new admin.',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password (min 6 characters)',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _emailController.clear();
                _nameController.clear();
                _passwordController.clear();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isAddingAdmin
                  ? null
                  : () {
                      setDialogState(() {});
                      _createAdmin();
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              child: _isAddingAdmin
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create Admin', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildAdminCard(Map<String, dynamic> admin) {
    final isCurrentUser = admin['id'] == _currentUserId;
    final isAdminSuperAdmin = admin['isSuperAdmin'] == true;
    final isDeleted = admin['isDeleted'] == true;

    // Don't show deleted admins
    if (isDeleted) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isAdminSuperAdmin
              ? Border.all(color: Colors.purple.withOpacity(0.3), width: 2)
              : null,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isAdminSuperAdmin
                    ? [Colors.purple.shade400, Colors.purple.shade600]
                    : [Colors.blue.shade400, Colors.blue.shade600],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAdminSuperAdmin ? Icons.star : Icons.admin_panel_settings,
              color: Colors.white,
              size: 22,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  admin['name'].isEmpty ? 'No Name' : admin['name'],
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: admin['isActive'] == false
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
              if (isCurrentUser)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'You',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                admin['email'],
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  // Role Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isAdminSuperAdmin
                            ? [Colors.purple.shade100, Colors.purple.shade50]
                            : [Colors.blue.shade100, Colors.blue.shade50],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isAdminSuperAdmin
                            ? Colors.purple.withOpacity(0.3)
                            : Colors.blue.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAdminSuperAdmin ? Icons.star : Icons.shield,
                          size: 12,
                          color: isAdminSuperAdmin ? Colors.purple : Colors.blue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isAdminSuperAdmin ? 'Super Admin' : 'Admin',
                          style: TextStyle(
                            fontSize: 11,
                            color: isAdminSuperAdmin ? Colors.purple : Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: admin['isActive'] == true
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          admin['isActive'] == true
                              ? Icons.check_circle
                              : Icons.cancel,
                          size: 12,
                          color: admin['isActive'] == true
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          admin['isActive'] == true ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 11,
                            color: admin['isActive'] == true
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Protection notice for super admin
              if (isAdminSuperAdmin)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(Icons.shield, size: 12, color: Colors.purple.shade300),
                      const SizedBox(width: 4),
                      Text(
                        'Protected - Cannot be deleted',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.purple.shade400,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          trailing: isCurrentUser || isAdminSuperAdmin
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Toggle Active/Inactive
                    IconButton(
                      icon: Icon(
                        admin['isActive'] == true ? Icons.pause_circle : Icons.play_circle,
                        color: admin['isActive'] == true ? Colors.orange : Colors.green,
                      ),
                      onPressed: () => _toggleAdminStatus(
                        admin['id'],
                        admin['isActive'] ?? true,
                        isAdminSuperAdmin,
                      ),
                      tooltip: admin['isActive'] == true ? 'Deactivate' : 'Activate',
                    ),
                    // Delete
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteAdmin(
                        admin['id'],
                        isAdminSuperAdmin,
                        admin['name'],
                      ),
                      tooltip: 'Delete Admin',
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Manage Admins',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAdmins,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAdminDialog,
        backgroundColor: Colors.purple,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add Admin', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade50, Colors.purple.shade100],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.star, color: Colors.purple, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Super Admin Access',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'You can create, modify, and delete other admins. Super admin is protected and cannot be deleted.',
                                style: TextStyle(
                                  color: Colors.purple[700],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Stats
                  Text(
                    '${_admins.where((a) => a['isDeleted'] != true).length} Administrators',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Admin List
                  Expanded(
                    child: _admins.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.admin_panel_settings,
                                    size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                const Text(
                                  'No Admins Found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Add your first admin to get started',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadAdmins,
                            color: Colors.purple,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _admins.length,
                              itemBuilder: (context, index) {
                                return _buildAdminCard(_admins[index]);
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
