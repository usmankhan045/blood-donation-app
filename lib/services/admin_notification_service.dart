import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to notify admins about profile updates and approval requests
class AdminNotificationService {
  static final AdminNotificationService _instance = AdminNotificationService._internal();
  factory AdminNotificationService() => _instance;
  AdminNotificationService._internal();

  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  /// Notify admins when a blood bank or hospital profile is updated
  Future<void> notifyProfileUpdate({
    required String userId,
    required String userEmail,
    required String role, // 'blood_bank' or 'hospital'
    required String name, // blood bank name or hospital name
    required bool isNewProfile, // true if first time completion, false if update
  }) async {
    try {
      final roleName = role == 'blood_bank' ? 'Blood Bank' : 'Hospital';
      
      // Create notification for all admins
      final adminsSnapshot = await _fs
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      for (final adminDoc in adminsSnapshot.docs) {
        final adminId = adminDoc.id;
        
        // Write to admin's notification inbox
        await _fs
            .collection('user_notifications')
            .doc(adminId)
            .collection('inbox')
            .add({
          'title': isNewProfile 
              ? 'New $roleName Profile Completion'
              : '$roleName Profile Updated',
          'body': isNewProfile
              ? '$name has completed their profile and is awaiting approval.'
              : '$name has updated their profile. Please review the changes.',
          'type': 'profile_update',
          'userId': userId,
          'userEmail': userEmail,
          'role': role,
          'name': name,
          'isNewProfile': isNewProfile,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      print('✅ Admin notification sent for profile update: $userId');
    } catch (e) {
      print('❌ Error notifying admins about profile update: $e');
    }
  }

  /// Notify admins when a new approval request is created
  Future<void> notifyNewApprovalRequest({
    required String userId,
    required String email,
    required String role,
  }) async {
    try {
      final roleName = role == 'blood_bank' ? 'Blood Bank' : 'Hospital';
      
      final adminsSnapshot = await _fs
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      for (final adminDoc in adminsSnapshot.docs) {
        final adminId = adminDoc.id;
        
        await _fs
            .collection('user_notifications')
            .doc(adminId)
            .collection('inbox')
            .add({
          'title': 'New $roleName Approval Request',
          'body': 'A new $roleName account ($email) is requesting approval.',
          'type': 'approval_request',
          'userId': userId,
          'userEmail': email,
          'role': role,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      print('✅ Admin notification sent for approval request: $userId');
    } catch (e) {
      print('❌ Error notifying admins about approval request: $e');
    }
  }

  /// Notify institution when their account is approved
  Future<void> notifyApprovalSuccess({
    required String userId,
    required String role,
  }) async {
    try {
      final roleName = role == 'blood_bank' ? 'Blood Bank' : 'Hospital';
      
      await _fs
          .collection('user_notifications')
          .doc(userId)
          .collection('inbox')
          .add({
        'title': 'Account Approved! 🎉',
        'body': 'Congratulations! Your $roleName account has been approved by the admin. You can now login and start using the app.',
        'type': 'account_approved',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Approval notification sent to user: $userId');
    } catch (e) {
      print('❌ Error notifying user about approval: $e');
    }
  }

  /// Notify institution when their account is rejected
  Future<void> notifyApprovalRejection({
    required String userId,
    required String role,
    String? reason,
  }) async {
    try {
      final roleName = role == 'blood_bank' ? 'Blood Bank' : 'Hospital';
      
      await _fs
          .collection('user_notifications')
          .doc(userId)
          .collection('inbox')
          .add({
        'title': 'Account Application Rejected',
        'body': reason != null && reason.isNotEmpty
            ? 'Your $roleName account application has been rejected. Reason: $reason'
            : 'Your $roleName account application has been rejected. Please contact support for more information.',
        'type': 'account_rejected',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Rejection notification sent to user: $userId');
    } catch (e) {
      print('❌ Error notifying user about rejection: $e');
    }
  }

  /// Get pending approval count for admin badge
  Future<int> getPendingApprovalsCount() async {
    try {
      final snapshot = await _fs
          .collection('approval_requests')
          .where('status', isEqualTo: 'pending')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('❌ Error getting pending approvals count: $e');
      return 0;
    }
  }

  /// Stream pending approvals count for real-time updates
  Stream<int> streamPendingApprovalsCount() {
    return _fs
        .collection('approval_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}

final adminNotificationService = AdminNotificationService();

