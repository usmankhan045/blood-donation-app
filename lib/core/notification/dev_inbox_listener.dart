// lib/services/notifications/dev_inbox_listener.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

          print('🔔 DevInboxListener: Showing notification - $title');

          // Show notification
          _showNotification(title, body, requestId, id, user.uid);

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

  /// Show the notification snackbar
  static void _showNotification(
    String title,
    String body,
    String requestId,
    String docId,
    String userId,
  ) {
    if (_context == null) {
      print('❌ DevInboxListener: Context is null');
      return;
    }

    try {
      final messenger = ScaffoldMessenger.maybeOf(_context!);
      if (messenger == null) {
        print('❌ DevInboxListener: ScaffoldMessenger not found');
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.notifications_active,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: 'VIEW',
            textColor: Colors.white,
            onPressed: () {
              // Mark as read when user taps View
              _markAsRead(userId, docId);
            },
          ),
          duration: const Duration(seconds: 8),
        ),
      );

      print('✅ DevInboxListener: Snackbar shown');

      // Auto-mark as read after showing
      Future.delayed(const Duration(seconds: 8), () {
        _markAsRead(userId, docId);
      });
    } catch (e) {
      print('❌ DevInboxListener: Error showing snackbar - $e');
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
