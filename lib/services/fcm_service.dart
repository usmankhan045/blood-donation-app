import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> sendNotification({
    required String token,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      print('🚀 SENDING REAL FCM NOTIFICATION:');
      print('   Token: ${token.length > 20 ? '${token.substring(0, 20)}...' : token}');
      print('   Title: $title');
      print('   Body: $body');
      print('   Data: $data');

      // Send REAL FCM notification using HTTP API (correct method)
      await _sendViaHttpAPI(
        token: token,
        title: title,
        body: body,
        data: data,
      );

      print('✅ REAL FCM notification sent successfully');
      print('   ──────────────────────────────────────────');

    } catch (e) {
      print('❌ Error sending real FCM notification: $e');
      throw Exception('Failed to send FCM notification: $e');
    }
  }

  // Helper method to send notification via HTTP API
  Future<void> _sendViaHttpAPI({
    required String token,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      final String serverKey = 'YOUR_FIREBASE_SERVER_KEY'; // You need to add this

      final Map<String, dynamic> notificationPayload = {
        'to': token,
        'notification': {
          'title': title,
          'body': body,
          'sound': 'default',
          'badge': '1',
        },
        'data': data,
        'android': {
          'priority': 'high',
          'notification': {
            'sound': 'default',
            'channel_id': 'high_importance_channel',
          },
        },
        'apns': {
          'payload': {
            'aps': {
              'alert': {
                'title': title,
                'body': body,
              },
              'sound': 'default',
              'badge': 1,
            },
          },
        },
      };

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode(notificationPayload),
      );

      if (response.statusCode == 200) {
        print('✅ FCM HTTP API call successful');
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == 1) {
          print('✅ FCM notification delivered successfully');
        } else {
          print('❌ FCM notification delivery failed: ${responseData}');
          throw Exception('FCM delivery failed: ${responseData}');
        }
      } else {
        print('❌ FCM HTTP API error: ${response.statusCode} - ${response.body}');
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Error in HTTP API call: $e');
      rethrow;
    }
  }

  Future<void> sendNotificationToMultiple({
    required List<String> tokens,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      print('🚀 SENDING REAL FCM NOTIFICATIONS TO ${tokens.length} DONORS');

      int successCount = 0;
      int failCount = 0;

      // Send to each token individually
      for (String token in tokens) {
        if (token.isNotEmpty && token != 'null') {
          try {
            await sendNotification(
              token: token,
              title: title,
              body: body,
              data: data,
            );
            successCount++;

            // Small delay to avoid rate limiting
            await Future.delayed(Duration(milliseconds: 100));
          } catch (e) {
            print('❌ Failed to send to token ${token.length > 10 ? token.substring(0, 10) : token}...: $e');
            failCount++;
          }
        } else {
          print('⚠️  Skipping empty or invalid token');
          failCount++;
        }
      }

      print('✅ Successfully sent notifications to $successCount out of ${tokens.length} donors');
      if (failCount > 0) {
        print('❌ Failed to send to $failCount donors');
      }
    } catch (e) {
      print('❌ Error sending notifications to multiple donors: $e');
    }
  }

  Future<void> sendEmergencyNotification({
    required String token,
    required String bloodType,
    required double distance,
    required int units,
    required String requestId,
  }) async {
    try {
      final title = '🚨 EMERGENCY: $bloodType Blood Needed Urgently!';
      final body = 'EMERGENCY: $bloodType blood needed ${distance.toStringAsFixed(1)}km away. '
          '$units unit(s) required immediately. Please respond ASAP!';

      await sendNotification(
        token: token,
        title: title,
        body: body,
        data: {
          'type': 'emergency_blood_request',
          'requestId': requestId,
          'bloodType': bloodType,
          'urgency': 'emergency',
          'distance': distance.toStringAsFixed(1),
          'units': units.toString(),
          'priority': 'high',
          'timestamp': DateTime.now().toIso8601String(),
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      );

      print('🚨 EMERGENCY notification sent successfully');
    } catch (e) {
      print('❌ Error sending emergency notification: $e');
    }
  }

  Future<void> testFCMToken(String userId) async {
    try {
      print('🧪 TESTING FCM TOKEN FOR USER: $userId');

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final userData = userDoc.data();

      if (userData == null) {
        print('❌ User document not found');
        return;
      }

      final fcmToken = userData['fcmToken'];
      final userName = userData['fullName'] ?? userData['name'] ?? 'Unknown';
      final userRole = userData['role'] ?? 'Unknown';
      final isAvailable = userData['isAvailable'] ?? false;
      final hasLocation = userData['location'] != null;

      print('👤 User Details:');
      print('   Name: $userName');
      print('   Role: $userRole');
      print('   Available: $isAvailable');
      print('   Has Location: $hasLocation');
      print('   FCM Token: ${fcmToken != null ? '${fcmToken.toString().substring(0, min(30, fcmToken.toString().length))}...' : 'MISSING ❌'}');

      if (fcmToken == null) {
        print('❌ CRITICAL: No FCM token found for donor $userName');

        String? currentToken = await _firebaseMessaging.getToken();
        if (currentToken != null) {
          print('💡 Current device FCM token: ${currentToken.substring(0, min(30, currentToken.length))}...');
          print('💡 Saving this token to user document...');
          await saveFCMTokenToUser(userId);
        }
      } else {
        print('✅ FCM token found and ready for notifications');

        await sendTestNotification(
          donorId: userId,
          bloodType: userData['bloodType'] ?? 'O+',
          distance: 2.5,
          urgency: 'test',
        );
      }

    } catch (e) {
      print('❌ Error testing FCM token: $e');
    }
  }

  int min(int a, int b) => a < b ? a : b;

  Future<void> sendTestNotification({
    required String donorId,
    required String bloodType,
    required double distance,
    String urgency = 'normal',
  }) async {
    try {
      print('🧪 SENDING REAL TEST NOTIFICATION TO DONOR: $donorId');

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(donorId).get();
      final userData = userDoc.data();

      if (userData == null || userData['fcmToken'] == null) {
        print('❌ Cannot send test notification: No FCM token found for donor $donorId');
        return;
      }

      final fcmToken = userData['fcmToken'];
      final donorName = userData['fullName'] ?? userData['name'] ?? 'Test Donor';

      await sendNotification(
        token: fcmToken,
        title: '🧪 TEST: Blood Request',
        body: 'TEST: $bloodType blood needed ${distance.toStringAsFixed(1)}km away. 1 unit required.',
        data: {
          'type': 'test_notification',
          'requestId': 'test-request-${DateTime.now().millisecondsSinceEpoch}',
          'bloodType': bloodType,
          'urgency': urgency,
          'distance': distance.toStringAsFixed(1),
          'donorId': donorId,
          'isTest': 'true',
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      );

      print('✅ REAL test notification sent to $donorName');

    } catch (e) {
      print('❌ Error sending test notification: $e');
    }
  }

  Future<String?> getCurrentDeviceToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      print('📱 Current device FCM token: ${token != null ? '${token.substring(0, min(30, token.length))}...' : 'null'}');
      return token;
    } catch (e) {
      print('❌ Error getting device FCM token: $e');
      return null;
    }
  }

  Future<void> saveFCMTokenToUser(String userId) async {
    try {
      String? token = await getCurrentDeviceToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ FCM token saved for user: $userId');
      } else {
        print('❌ No FCM token available to save');
      }
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  Future<void> checkFCMHealth() async {
    try {
      print('🏥 CHECKING FCM SERVICE HEALTH...');

      final apnsToken = await _firebaseMessaging.getAPNSToken();
      final token = await _firebaseMessaging.getToken();

      print('   Firebase Messaging Status: ✅ ACTIVE');
      print('   APNS Token: ${apnsToken != null ? "Available" : "Not available"}');
      print('   FCM Token: ${token != null ? "Available" : "Not available"}');

      print('✅ FCM Service Health: EXCELLENT');
    } catch (e) {
      print('❌ FCM Service Health Check Failed: $e');
    }
  }

  Future<void> initializeFCM() async {
    try {
      print('🔄 INITIALIZING FCM SERVICE...');

      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      print('✅ Notification permission: ${settings.authorizationStatus}');

      String? token = await getCurrentDeviceToken();
      if (token != null) {
        print('✅ FCM token obtained: ${token.substring(0, min(20, token.length))}...');

        // Save token to current user if logged in
        // You'll need to implement this based on your auth system
        // await saveFCMTokenToUser(currentUserId);
      } else {
        print('❌ Failed to get FCM token');
      }

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('📱 Foreground FCM message received:');
        print('   Title: ${message.notification?.title}');
        print('   Body: ${message.notification?.body}');
        print('   Data: ${message.data}');

        // You can show a local notification here
        _showLocalNotification(message);
      });

      // Handle when app is opened from terminated state
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('👆 FCM message opened from terminated state:');
        print('   Data: ${message.data}');
        _handleNotificationClick(message.data);
      });

      // Handle initial notification when app is opened from terminated state
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        print('👆 Initial FCM message: ${initialMessage.data}');
        _handleNotificationClick(initialMessage.data);
      }

      print('✅ FCM Service Initialized Successfully');
    } catch (e) {
      print('❌ FCM Service Initialization Failed: $e');
    }
  }

  void _showLocalNotification(RemoteMessage message) {
    // You can use flutter_local_notifications package here
    // to show a local notification when app is in foreground
    print('🎯 Should show local notification: ${message.notification?.title}');
  }

  void _handleNotificationClick(Map<String, dynamic> data) {
    print('🎯 Handling notification click with data: $data');

    // Handle navigation based on notification type
    final type = data['type'];
    switch (type) {
      case 'emergency_blood_request':
      case 'blood_request':
        final requestId = data['requestId'];
        print('🔗 Navigate to request details: $requestId');
        break;
      case 'test_notification':
        print('🔗 Test notification clicked');
        break;
      default:
        print('🔗 Unknown notification type: $type');
    }
  }
}

final fcmService = FCMService();