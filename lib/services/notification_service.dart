import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/blood_request_model.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Initialize FCM with enhanced setup
  Future<void> initializeFCM() async {
    // Request permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print('Notification permission: ${settings.authorizationStatus}');

    // Get and save FCM token
    String? fcmToken = await _firebaseMessaging.getToken();
    print("FCM Token: $fcmToken");

    if (fcmToken != null) {
      await _saveFcmToken(fcmToken);
    }

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen(_saveFcmToken);

    // Handle different message types
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  // Save FCM token to Firestore
  Future<void> _saveFcmToken(String token) async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _fs.collection('users').doc(user.uid).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        print('FCM token saved for user: ${user.uid}');
      } catch (e) {
        print('Error saving FCM token: $e');
      }
    }
  }

  // Handle foreground messages with enhanced UI
  void _handleForegroundMessage(RemoteMessage message) {
    print('Foreground message: ${message.data}');

    final data = message.data;
    final notification = message.notification;

    if (navigatorKey.currentContext != null) {
      _showInAppNotification(
        title: notification?.title ?? data['title'] ?? 'New Notification',
        body: notification?.body ?? data['body'] ?? '',
        requestId: data['requestId'],
        type: data['type'],
      );
    }
  }

  // Background message handler
  @pragma('vm:entry-point')
  static Future<void> _backgroundMessageHandler(RemoteMessage message) async {
    print("Background message: ${message.notification?.title}");

    // You can process background messages here
    // For example, update local database or trigger other background tasks
  }

  // Handle when user taps on notification
  void _handleMessageOpenedApp(RemoteMessage message) {
    print('Message opened: ${message.data}');

    final data = message.data;
    final requestId = data['requestId'];
    final type = data['type'];

    if (requestId != null && navigatorKey.currentContext != null) {
      _navigateToRequest(requestId, type);
    }
  }

  // Show in-app notification with action
  void _showInAppNotification({
    required String title,
    required String body,
    String? requestId,
    String? type,
  }) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            if (body.isNotEmpty)
              Text(body, style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.blueGrey[800],
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 6),
        action: requestId != null ? SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () => _navigateToRequest(requestId, type),
        ) : null,
      ),
    );
  }

  // Navigate to appropriate screen based on notification type
  void _navigateToRequest(String requestId, String? type) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    if (type == 'blood_request') {
      // Navigate to donor requests screen
      Navigator.pushNamed(context, '/donor_requests', arguments: {'requestId': requestId});
    } else if (type == 'request_accepted') {
      // Navigate to recipient request details
      Navigator.pushNamed(context, '/recipient_requests', arguments: {'requestId': requestId});
    } else if (type == 'donation_completed') {
      // Navigate to completed requests
      Navigator.pushNamed(context, '/completed_requests', arguments: {'requestId': requestId});
    }
  }

  // Send blood request notification to donors
  Future<void> sendBloodRequestNotification({
    required String donorFcmToken,
    required BloodRequest request,
    required double distance,
  }) async {
    try {
      final title = _getRequestNotificationTitle(request.urgency);
      final body = _getRequestNotificationBody(request, distance);

      // Store notification in user's inbox
      await _storeNotificationInInbox(
        userId: _getUserIdFromToken(donorFcmToken), // Extract user ID from token context
        title: title,
        body: body,
        type: 'blood_request',
        requestId: request.id,
      );

      // Send push notification
      await _sendPushNotification(
        token: donorFcmToken,
        title: title,
        body: body,
        data: {
          'type': 'blood_request',
          'requestId': request.id,
          'urgency': request.urgency,
          'bloodType': request.bloodType,
          'distance': distance.toStringAsFixed(1),
        },
      );

      print('Blood request notification sent to donor');
    } catch (e) {
      print('Error sending blood request notification: $e');
    }
  }

  // Send notification when request is accepted
  Future<void> sendRequestAcceptedNotification({
    required String recipientFcmToken,
    required String requestId,
    required String donorName,
  }) async {
    try {
      const title = 'Request Accepted! 🎉';
      final body = '$donorName has accepted your blood request';

      // Store in recipient's inbox
      await _storeNotificationInInbox(
        userId: _getUserIdFromToken(recipientFcmToken),
        title: title,
        body: body,
        type: 'request_accepted',
        requestId: requestId,
      );

      // Send push notification
      await _sendPushNotification(
        token: recipientFcmToken,
        title: title,
        body: body,
        data: {
          'type': 'request_accepted',
          'requestId': requestId,
          'donorName': donorName,
        },
      );

      print('Request accepted notification sent to recipient');
    } catch (e) {
      print('Error sending request accepted notification: $e');
    }
  }

  // NEW: Send donation completed notification
  Future<void> sendDonationCompletedNotification({
    required String recipientFcmToken,
    required String requestId,
    required String donorName,
  }) async {
    try {
      const title = 'Donation Completed! ✅';
      final body = 'Blood donation from $donorName has been completed successfully. Thank you for saving a life!';

      // Store in recipient's inbox
      await _storeNotificationInInbox(
        userId: _getUserIdFromToken(recipientFcmToken),
        title: title,
        body: body,
        type: 'donation_completed',
        requestId: requestId,
      );

      // Send push notification
      await _sendPushNotification(
        token: recipientFcmToken,
        title: title,
        body: body,
        data: {
          'type': 'donation_completed',
          'requestId': requestId,
          'donorName': donorName,
        },
      );

      print('Donation completed notification sent');
    } catch (e) {
      print('Error sending donation completed notification: $e');
    }
  }

  // Send notification to donor when they complete a donation
  Future<void> sendDonorCompletionNotification({
    required String donorFcmToken,
    required String requestId,
  }) async {
    try {
      const title = 'Donation Recorded! 🙏';
      final body = 'Thank you for your life-saving donation! Your contribution has been recorded.';

      // Store in donor's inbox
      await _storeNotificationInInbox(
        userId: _getUserIdFromToken(donorFcmToken),
        title: title,
        body: body,
        type: 'donation_recorded',
        requestId: requestId,
      );

      // Send push notification
      await _sendPushNotification(
        token: donorFcmToken,
        title: title,
        body: body,
        data: {
          'type': 'donation_recorded',
          'requestId': requestId,
        },
      );

      print('Donor completion notification sent');
    } catch (e) {
      print('Error sending donor completion notification: $e');
    }
  }

  // Store notification in user's inbox for persistence
  Future<void> _storeNotificationInInbox({
    required String userId,
    required String title,
    required String body,
    required String type,
    required String requestId,
  }) async {
    try {
      await _fs
          .collection('user_notifications')
          .doc(userId)
          .collection('inbox')
          .add({
        'title': title,
        'body': body,
        'type': type,
        'requestId': requestId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error storing notification in inbox: $e');
    }
  }

  // Enhanced push notification sending
  Future<void> _sendPushNotification({
    required String token,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      // This should be implemented with your backend server
      // For now, we'll use the HTTP method (replace with your server URL)

      final response = await http.post(
        Uri.parse('https://your-backend.com/send-notification'), // Replace with your endpoint
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'to': token,
          'notification': <String, dynamic>{
            'title': title,
            'body': body,
            'sound': 'default',
          },
          'data': data,
          'android': <String, dynamic>{
            'priority': 'high',
          },
          'apns': <String, dynamic>{
            'payload': <String, dynamic>{
              'aps': <String, dynamic>{
                'sound': 'default',
                'badge': 1,
              },
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        print('Push notification sent successfully');
      } else {
        print('Failed to send push notification: ${response.body}');
      }
    } catch (e) {
      print('Error in _sendPushNotification: $e');
      // Fallback: Use local notifications or other methods
    }
  }

  // NEW: Simple sendNotification method for RequestProvider compatibility
  Future<void> sendNotification({
    required String title,
    required String body,
    required String recipientToken,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _sendPushNotification(
        token: recipientToken,
        title: title,
        body: body,
        data: data ?? {},
      );
      print('Notification sent to $recipientToken');
    } catch (e) {
      print('Error in sendNotification: $e');
    }
  }

  // Helper method to extract user ID from token context
  String _getUserIdFromToken(String token) {
    // In a real app, you'd have a mapping between tokens and user IDs
    // For now, we'll use the current user's ID or create a placeholder
    final currentUser = _auth.currentUser;
    return currentUser?.uid ?? 'unknown_user';
  }

  // Helper methods for notification content
  String _getRequestNotificationTitle(String urgency) {
    switch (urgency) {
      case 'emergency':
        return '🚨 EMERGENCY Blood Request';
      case 'high':
        return '⚠️ Urgent Blood Needed';
      case 'normal':
        return '🩸 Blood Donation Request';
      case 'low':
        return 'Blood Donation Opportunity';
      default:
        return 'Blood Donation Request';
    }
  }

  String _getRequestNotificationBody(BloodRequest request, double distance) {
    final distanceText = distance < 1
        ? '${(distance * 1000).round()}m away'
        : '${distance.toStringAsFixed(1)}km away';

    final urgencyText = request.urgency == 'emergency' ? 'URGENT: ' : '';

    return '$urgencyText${request.bloodType} blood needed $distanceText. ${request.units} unit(s) required.';
  }

  // Get user's unread notifications
  Stream<List<Map<String, dynamic>>> getUserNotifications(String userId) {
    return _fs
        .collection('user_notifications')
        .doc(userId)
        .collection('inbox')
        .where('read', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'title': data['title'] ?? '',
        'body': data['body'] ?? '',
        'type': data['type'] ?? '',
        'requestId': data['requestId'] ?? '',
        'createdAt': data['createdAt'],
        'read': data['read'] ?? false,
      };
    })
        .toList());
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String userId, String notificationId) async {
    try {
      await _fs
          .collection('user_notifications')
          .doc(userId)
          .collection('inbox')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      final notifications = await _fs
          .collection('user_notifications')
          .doc(userId)
          .collection('inbox')
          .where('read', isEqualTo: false)
          .get();

      final batch = _fs.batch();
      for (final doc in notifications.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Get current user's FCM token
  Future<String?> getCurrentUserToken() async {
    return await _firebaseMessaging.getToken();
  }

  // Subscribe to topics
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
  }

  // Unsubscribe from topics
  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
  }

  // Clean up
  void dispose() {
    // Clean up any listeners if needed
  }
}