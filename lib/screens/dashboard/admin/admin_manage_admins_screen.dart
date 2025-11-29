import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', whereIn: ['admin', 'super_admin'])
          .get();

      setState(() {
        _admins = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? '',
            'email': data['email'] ?? '',
            'role': data['role'] ?? 'admin',
            'isSuperAdmin': data['isSuperAdmin'] ?? false,
            'createdAt': data['createdAt'],
            'isActive': data['isActive'] ?? true,
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading admins: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createAdmin() async {
    if (_emailController.text.isEmpty ||
        _nameController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      _showError('Please fill all fields');
      return;
    }

    setState(() {
      _isAddingAdmin = true;
    });

    try {
      // Create user in Firebase Auth
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
        'isSuperAdmin': false,
        'createdAt': DateTime.now(),
        'isActive': true,
      });

      // Clear form
      _emailController.clear();
      _nameController.clear();
      _passwordController.clear();

      // Reload admins list
      await _loadAdmins();

      _showSuccess('Admin created successfully!');
    } catch (e) {
      _showError('Error creating admin: ${e.toString()}');
    } finally {
      setState(() {
        _isAddingAdmin = false;
      });
    }
  }

  Future<void> _toggleAdminStatus(String adminId, bool currentStatus) async {
    try {
      await _firestore.collection('users').doc(adminId).update({
        'isActive': !currentStatus,
      });

      await _loadAdmins();
      _showSuccess('Admin status updated!');
    } catch (e) {
      _showError('Error updating admin status');
    }
  }

  Future<void> _deleteAdmin(String adminId) async {
    final result = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Admin'),
        content: const Text('Are you sure you want to delete this admin? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _firestore.collection('users').doc(adminId).delete();
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
      builder: (context) => AlertDialog(
        title: const Text('Add New Admin'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isAddingAdmin ? null : _createAdmin,
            child: _isAddingAdmin
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text('Create Admin'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context); // Close the dialog
  }

  Widget _buildAdminCard(Map<String, dynamic> admin) {
    final isCurrentUser = admin['id'] == _auth.currentUser?.uid;

    return Card(
      elevation: 2,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: admin['isSuperAdmin']
                ? Colors.purple.withOpacity(0.2)
                : Colors.blue.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            admin['isSuperAdmin'] ? Icons.star : Icons.admin_panel_settings,
            color: admin['isSuperAdmin'] ? Colors.purple : Colors.blue,
          ),
        ),
        title: Text(
          admin['name'],
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: admin['isActive'] ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(admin['email']),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: admin['isSuperAdmin']
                        ? Colors.purple.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    admin['isSuperAdmin'] ? 'Super Admin' : 'Admin',
                    style: TextStyle(
                      fontSize: 12,
                      color: admin['isSuperAdmin'] ? Colors.purple : Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: admin['isActive']
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    admin['isActive'] ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 12,
                      color: admin['isActive'] ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: isCurrentUser
            ? const Text('Current User')
            : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                admin['isActive'] ? Icons.pause : Icons.play_arrow,
                color: admin['isActive'] ? Colors.orange : Colors.green,
              ),
              onPressed: () => _toggleAdminStatus(admin['id'], admin['isActive']),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteAdmin(admin['id']),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Admins'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAdmins,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddAdminDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.blue.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'As a Super Admin, you can create new admins and manage existing ones.',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _admins.isEmpty
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.admin_panel_settings, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No Admins Found',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Add your first admin to get started',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: _admins.length,
                itemBuilder: (context, index) {
                  return _buildAdminCard(_admins[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}