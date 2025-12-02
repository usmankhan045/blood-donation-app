import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme.dart';
import '../../../widgets/custom_snackbar.dart';

/// 🔐 ADMIN VERIFY INSTITUTIONS SCREEN
/// Allows admin to approve or reject blood bank and hospital account registrations
class AdminVerifyUsersScreen extends StatefulWidget {
  const AdminVerifyUsersScreen({Key? key}) : super(key: key);

  @override
  State<AdminVerifyUsersScreen> createState() => _AdminVerifyUsersScreenState();
}

class _AdminVerifyUsersScreenState extends State<AdminVerifyUsersScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BloodAppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Verify Institutions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: BloodAppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Debug button to check Firestore
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Debug Firestore',
            onPressed: () => _debugFirestore(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => setState(() {}),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            _buildTabWithBadge('Pending', 'pending'),
            const Tab(icon: Icon(Icons.check_circle, size: 20), text: 'Approved'),
            const Tab(icon: Icon(Icons.cancel, size: 20), text: 'Rejected'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(),
          _buildApprovedTab(),
          _buildRejectedTab(),
        ],
      ),
    );
  }

  /// Debug function to check what's in Firestore
  Future<void> _debugFirestore() async {
    try {
      // Check approval_requests collection
      final approvalDocs = await _firestore.collection('approval_requests').get();
      debugPrint('=== DEBUG: approval_requests collection ===');
      debugPrint('Total documents: ${approvalDocs.docs.length}');
      
      for (final doc in approvalDocs.docs) {
        final data = doc.data();
        debugPrint('  - ID: ${doc.id}');
        debugPrint('    Status: ${data['status']}');
        debugPrint('    Email: ${data['email']}');
        debugPrint('    Role: ${data['role']}');
        debugPrint('    RequestedAt: ${data['requestedAt']}');
      }

      // Check users with pending approval
      final pendingUsers = await _firestore
          .collection('users')
          .where('approvalStatus', isEqualTo: 'pending')
          .get();
      debugPrint('\n=== DEBUG: Users with pending approval ===');
      debugPrint('Total: ${pendingUsers.docs.length}');
      
      for (final doc in pendingUsers.docs) {
        final data = doc.data();
        debugPrint('  - UID: ${doc.id}');
        debugPrint('    Email: ${data['email']}');
        debugPrint('    Role: ${data['role']}');
        debugPrint('    isApproved: ${data['isApproved']}');
      }

      // Show dialog with results
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Debug Results'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('approval_requests: ${approvalDocs.docs.length} docs',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (approvalDocs.docs.isEmpty)
                    const Text('No approval requests found in Firestore!',
                      style: TextStyle(color: Colors.red)),
                  ...approvalDocs.docs.map((doc) {
                    final data = doc.data();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${data['email']} (${data['status']})',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }),
                  const Divider(),
                  Text('Users pending: ${pendingUsers.docs.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (pendingUsers.docs.isEmpty)
                    const Text('No users with pending approval status!',
                      style: TextStyle(color: Colors.orange)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _createTestApprovalRequest();
                },
                child: const Text('Create Test Request'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Debug error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Debug error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Create a test approval request to verify Firestore write permissions
  Future<void> _createTestApprovalRequest() async {
    try {
      final testId = 'test_${DateTime.now().millisecondsSinceEpoch}';
      
      await _firestore.collection('approval_requests').doc(testId).set({
        'userId': testId,
        'email': 'test@example.com',
        'role': 'blood_bank',
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
        'isTest': true,
      });

      debugPrint('✅ Test approval request created with ID: $testId');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test request created! ID: $testId'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Delete',
              textColor: Colors.white,
              onPressed: () async {
                await _firestore.collection('approval_requests').doc(testId).delete();
                setState(() {});
              },
            ),
          ),
        );
        setState(() {}); // Refresh the list
      }
    } catch (e) {
      debugPrint('❌ Error creating test request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create test request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTabWithBadge(String text, String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('approval_requests')
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Tab(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pending_actions, size: 18),
                const SizedBox(width: 4),
                Text(text, style: const TextStyle(fontSize: 13)),
                if (count > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingTab() {
    return StreamBuilder<QuerySnapshot>(
      // 🔧 FIX: Removed orderBy to avoid Firestore composite index requirement
      stream: _firestore
          .collection('approval_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(BloodAppTheme.primary),
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint('Error loading pending requests: ${snapshot.error}');
          return _buildErrorState('Error loading pending requests: ${snapshot.error}');
        }

        final docs = snapshot.data?.docs ?? [];
        debugPrint('📋 Pending approval requests count: ${docs.length}');

        // Sort by requestedAt on client side
        docs.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['requestedAt'] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['requestedAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime); // descending
        });

        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.check_circle_outline,
            title: 'No Pending Requests',
            subtitle: 'All institution registrations have been processed',
            color: BloodAppTheme.success,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final request = docs[index];
            return _buildApprovalCard(request, isPending: true);
          },
        );
      },
    );
  }

  Widget _buildApprovedTab() {
    return StreamBuilder<QuerySnapshot>(
      // 🔧 FIX: Removed orderBy to avoid Firestore composite index requirement
      stream: _firestore
          .collection('approval_requests')
          .where('status', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(BloodAppTheme.primary),
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint('Error loading approved requests: ${snapshot.error}');
          return _buildErrorState('Error loading approved requests');
        }

        final docs = snapshot.data?.docs ?? [];
        
        // Sort by processedAt on client side
        docs.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['processedAt'] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['processedAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime); // descending
        });

        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.verified_user_outlined,
            title: 'No Approved Institutions',
            subtitle: 'Approved institutions will appear here',
            color: BloodAppTheme.info,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final request = docs[index];
            return _buildApprovalCard(request, isPending: false, isApproved: true);
          },
        );
      },
    );
  }

  Widget _buildRejectedTab() {
    return StreamBuilder<QuerySnapshot>(
      // 🔧 FIX: Removed orderBy to avoid Firestore composite index requirement
      stream: _firestore
          .collection('approval_requests')
          .where('status', isEqualTo: 'rejected')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(BloodAppTheme.primary),
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint('Error loading rejected requests: ${snapshot.error}');
          return _buildErrorState('Error loading rejected requests');
        }

        final docs = snapshot.data?.docs ?? [];
        
        // Sort by processedAt on client side
        docs.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['processedAt'] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['processedAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime); // descending
        });

        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.block_outlined,
            title: 'No Rejected Applications',
            subtitle: 'Rejected applications will appear here',
            color: BloodAppTheme.error,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final request = docs[index];
            return _buildApprovalCard(request, isPending: false, isApproved: false);
          },
        );
      },
    );
  }

  Widget _buildApprovalCard(DocumentSnapshot request,
      {required bool isPending, bool isApproved = false}) {
    final data = request.data() as Map<String, dynamic>;
    final userId = data['userId'] as String? ?? request.id;
    final email = data['email'] as String? ?? 'No email';
    final role = data['role'] as String? ?? 'unknown';
    final status = data['status'] as String? ?? 'pending';
    final requestedAt = data['requestedAt'] as Timestamp?;
    final processedAt = data['processedAt'] as Timestamp?;
    final rejectionReason = data['rejectionReason'] as String?;

    final isHospital = role == 'hospital';
    final roleName = isHospital ? 'Hospital' : 'Blood Bank';
    final roleIcon = isHospital ? Icons.local_hospital : Icons.bloodtype;
    final roleColor = isHospital ? BloodAppTheme.info : BloodAppTheme.accent;

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(userId).get(),
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final name = userData?['hospitalName'] ??
            userData?['bloodBankName'] ??
            userData?['name'] ??
            email.split('@').first;
        final phone = userData?['phone'] as String?;
        final address = userData?['address'] as String?;
        final profileCompleted = userData?['profileCompleted'] ?? false;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      roleColor.withOpacity(0.1),
                      roleColor.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(roleIcon, color: roleColor, size: 26),
                    ),
                    const SizedBox(width: 14),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: BloodAppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            roleName,
                            style: TextStyle(
                              color: roleColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status Badge
                    _buildStatusBadge(status),
                  ],
                ),
              ),

              // Details
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.email_outlined, 'Email', email),
                    if (phone != null && phone.isNotEmpty)
                      _buildInfoRow(Icons.phone_outlined, 'Phone', phone),
                    if (address != null && address.isNotEmpty)
                      _buildInfoRow(Icons.location_on_outlined, 'Address', address),
                    _buildInfoRow(
                      Icons.verified_user_outlined,
                      'Profile Status',
                      profileCompleted ? 'Completed' : 'Incomplete',
                      valueColor: profileCompleted
                          ? BloodAppTheme.success
                          : BloodAppTheme.warning,
                    ),
                    if (requestedAt != null)
                      _buildInfoRow(
                        Icons.access_time,
                        'Requested',
                        _formatDate(requestedAt.toDate()),
                      ),
                    if (processedAt != null)
                      _buildInfoRow(
                        Icons.update,
                        'Processed',
                        _formatDate(processedAt.toDate()),
                      ),
                    if (rejectionReason != null && rejectionReason.isNotEmpty)
                      _buildInfoRow(
                        Icons.info_outline,
                        'Rejection Reason',
                        rejectionReason,
                        valueColor: BloodAppTheme.error,
                      ),
                  ],
                ),
              ),

              // Actions
              if (isPending)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showRejectDialog(userId, role),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: BloodAppTheme.error,
                            side: const BorderSide(color: BloodAppTheme.error),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _approveAccount(userId),
                          icon: const Icon(Icons.check, size: 18, color: Colors.white),
                          label: const Text('Approve', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BloodAppTheme.success,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;
    String text;

    switch (status) {
      case 'approved':
        color = BloodAppTheme.success;
        icon = Icons.check_circle;
        text = 'APPROVED';
        break;
      case 'rejected':
        color = BloodAppTheme.error;
        icon = Icons.cancel;
        text = 'REJECTED';
        break;
      default:
        color = BloodAppTheme.warning;
        icon = Icons.pending;
        text = 'PENDING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: BloodAppTheme.textHint),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: BloodAppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? BloodAppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: color),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: BloodAppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: BloodAppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: BloodAppTheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: BloodAppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Retry', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: BloodAppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveAccount(String userId) async {
    try {
      // Update user document
      await _firestore.collection('users').doc(userId).update({
        'isApproved': true,
        'approvalStatus': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      // Update approval request
      await _firestore.collection('approval_requests').doc(userId).update({
        'status': 'approved',
        'processedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          'Account Approved!',
          subtitle: 'The institution can now login and use the app.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Error: $e');
      }
    }
  }

  Future<void> _showRejectDialog(String userId, String role) async {
    final reasonController = TextEditingController();
    final roleName = role == 'hospital' ? 'Hospital' : 'Blood Bank';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: BloodAppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning, color: BloodAppTheme.error),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Reject Application'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to reject this $roleName application?',
              style: TextStyle(color: BloodAppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Rejection Reason (optional)',
                hintText: 'Provide a reason for rejection...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _rejectAccount(userId, reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: BloodAppTheme.error,
            ),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectAccount(String userId, String reason) async {
    try {
      // Update user document
      await _firestore.collection('users').doc(userId).update({
        'isApproved': false,
        'approvalStatus': 'rejected',
        'rejectionReason': reason.isEmpty ? null : reason,
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      // Update approval request
      await _firestore.collection('approval_requests').doc(userId).update({
        'status': 'rejected',
        'rejectionReason': reason.isEmpty ? null : reason,
        'processedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        AppSnackbar.showWarning(
          context,
          'Application Rejected',
          subtitle: 'The application has been rejected.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Error: $e');
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes} minutes ago';
      }
      return '${diff.inHours} hours ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
