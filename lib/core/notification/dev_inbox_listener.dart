// lib/services/notifications/dev_inbox_listener.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../widgets/custom_snackbar.dart';
import '../../services/navigation_service.dart';

class DevInboxListener {
  DevInboxListener._();

  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  static BuildContext? _context;
  static Set<String> _shownNotifications = {}; // Track shown notifications

  /// Call in donor dashboard initState: DevInboxListener.attach(context);
  static Future<void> attach(BuildContext context) async {
    // Avoid double attach
    await dispose();
    _context = context;
    _shownNotifications.clear();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ DevInboxListener: No user logged in');
      return;
    }

    print('🔔 DevInboxListener: Attaching for user ${user.uid}');

    // Query without orderBy to avoid index requirement
    final query = FirebaseFirestore.instance
        .collection('user_notifications')
        .doc(user.uid)
        .collection('inbox')
        .where('read', isEqualTo: false);

    _sub = query.snapshots().listen(
      (snap) {
        print(
          '🔔 DevInboxListener: Got ${snap.docs.length} unread notifications',
        );

        if (snap.docs.isEmpty) {
          print('🔔 DevInboxListener: No unread notifications');
          return;
        }

        // Process each unread notification
        for (final doc in snap.docs) {
          final id = doc.id;

          // Skip if already shown in this session
          if (_shownNotifications.contains(id)) {
            continue;
          }

          final data = doc.data();
          final title = (data['title'] ?? 'New notification').toString();
          final body = (data['body'] ?? '').toString();
          final requestId = (data['requestId'] ?? '').toString();
          final type = (data['type'] ?? '').toString();
          final threadId = (data['threadId'] ?? '').toString();
          final targetType = (data['targetType'] ?? '').toString();

          print('🔔 DevInboxListener: Showing notification - $title (type: $type)');

          // Show notification with navigation support
          _showNotification(
            title,
            body,
            requestId,
            id,
            user.uid,
            type: type.isNotEmpty ? type : null,
            threadId: threadId.isNotEmpty ? threadId : null,
            targetType: targetType.isNotEmpty ? targetType : null,
          );

          // Mark as shown in this session
          _shownNotifications.add(id);

          // Only show one at a time
          break;
        }
      },
      onError: (error) {
        print('❌ DevInboxListener error: $error');
      },
    );

    print('✅ DevInboxListener: Attached successfully');

    // Also check for existing unread notifications immediately
    await checkUnreadNotifications();
  }

  /// Show the notification snackbar using the new top snackbar system
  static void _showNotification(
    String title,
    String body,
    String requestId,
    String docId,
    String userId, {
    String? type,
    String? threadId,
    String? targetType,
  }) {
    if (_context == null) {
      print('❌ DevInboxListener: Context is null');
      return;
    }

    try {
      // Use the new modern top snackbar
      AppSnackbar.showNotification(
        _context!,
        title: title,
        body: body,
        type: type,
        requestId: requestId,
        threadId: threadId,
        onTap: () {
          // Mark as read when user taps
          _markAsRead(userId, docId);
          
          // Navigate based on notification type
          _navigateToNotification(type, requestId, threadId, targetType);
        },
      );

      print('✅ DevInboxListener: Top snackbar shown');

      // Auto-mark as read after snackbar disappears
      Future.delayed(const Duration(seconds: 3), () {
        _markAsRead(userId, docId);
      });
    } catch (e) {
      print('❌ DevInboxListener: Error showing snackbar - $e');
    }
  }
  
  /// Navigate to the appropriate screen based on notification type
  static void _navigateToNotification(
    String? type,
    String requestId,
    String? threadId,
    String? targetType,
  ) {
    switch (type) {
      case 'blood_request':
      case 'emergency_blood_request':
        if (targetType == 'donor') {
          NavigationService.instance.navigateTo('/donor_requests');
        } else if (targetType == 'blood_bank') {
          NavigationService.instance.navigateTo('/blood_bank_dashboard');
        } else if (targetType == 'hospital') {
          NavigationService.instance.navigateTo('/hospital/my_requests');
        } else {
          NavigationService.instance.navigateTo('/donor_requests');
        }
        break;
      case 'request_accepted':
        if (targetType == 'recipient') {
          NavigationService.instance.navigateTo('/recipient/my_requests');
        } else if (targetType == 'hospital') {
          NavigationService.instance.navigateTo('/hospital/my_requests');
        } else {
          NavigationService.instance.navigateTo('/recipient/my_requests');
        }
        break;
      case 'chat_message':
        NavigationService.instance.navigateTo('/chats');
        break;
      case 'fulfillment_reminder':
        NavigationService.instance.navigateTo('/blood_bank_dashboard');
        break;
      default:
        // For unknown types, try to navigate based on targetType
        if (targetType == 'donor') {
          NavigationService.instance.navigateTo('/donor_requests');
        } else if (targetType == 'blood_bank') {
          NavigationService.instance.navigateTo('/blood_bank_dashboard');
        } else if (targetType == 'hospital') {
          NavigationService.instance.navigateTo('/hospital/my_requests');
        } else if (targetType == 'recipient') {
          NavigationService.instance.navigateTo('/recipient/my_requests');
        }
    }
  }

  /// Mark notification as read
  static Future<void> _markAsRead(String userId, String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('user_notifications')
          .doc(userId)
          .collection('inbox')
          .doc(docId)
          .update({'read': true});
      print('✅ DevInboxListener: Marked notification $docId as read');
    } catch (e) {
      print('❌ DevInboxListener: Error marking as read - $e');
    }
  }

  /// Manually check for unread notifications (call on screen refresh)
  static Future<int> checkUnreadNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('user_notifications')
              .doc(user.uid)
              .collection('inbox')
              .where('read', isEqualTo: false)
              .get();

      final count = snapshot.docs.length;
      print('🔔 DevInboxListener: Found $count unread notifications');

      return count;
    } catch (e) {
      print('❌ DevInboxListener: Error checking unread - $e');
      return 0;
    }
  }

  /// Get unread notification count as stream
  static Stream<int> getUnreadCountStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);

    return FirebaseFirestore.instance
        .collection('user_notifications')
        .doc(user.uid)
        .collection('inbox')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _context = null;
    _shownNotifications.clear();
    print('🔔 DevInboxListener: Disposed');
  }
}
