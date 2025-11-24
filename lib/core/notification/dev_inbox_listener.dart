// lib/services/notifications/dev_inbox_listener.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DevInboxListener {
  DevInboxListener._();

  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  /// Call in donor dashboard initState: DevInboxListener.attach(context);
  static Future<void> attach(BuildContext context) async {
    // Avoid double attach
    await dispose();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final query = FirebaseFirestore.instance
        .collection('user_notifications')
        .doc(user.uid)
        .collection('inbox')
        .where('read', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(1);

    _sub = query.snapshots().listen((snap) {
      if (snap.docs.isEmpty) return;
      final data = snap.docs.first.data();
      final id = snap.docs.first.id;

      final type = (data['type'] ?? '').toString();
      final title = (data['title'] ?? 'New notification').toString();
      final body = (data['body'] ?? '').toString();
      final requestId = (data['requestId'] ?? '').toString();

      // Show a simple in-app notification
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (body.isNotEmpty) Text(body),
              ],
            ),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                // Navigate to your donor requests screen or a specific detail
                // You can push a detail screen with requestId if you have one
                // For now we'll rely on the donor list page to show it.
              },
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      }

      // mark read
      FirebaseFirestore.instance
          .collection('user_notifications')
          .doc(user.uid)
          .collection('inbox')
          .doc(id)
          .update({'read': true}).catchError((_) {});
    });
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
