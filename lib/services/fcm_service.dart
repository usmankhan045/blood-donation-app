import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart' as auth;

/// 🔥 PRODUCTION-READY FCM SERVICE WITH ACTUAL DELIVERY
/// Sends notifications directly via FCM HTTP v1 API
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _cachedAccessToken;
  DateTime? _tokenExpiry;

  // ═══════════════════════════════════════════════════════════════
  // 🔐 GET OAUTH2 ACCESS TOKEN FROM SERVICE ACCOUNT
  // ═══════════════════════════════════════════════════════════════

  Future<String> _getAccessToken() async {
    try {
      if (_cachedAccessToken != null &&
          _tokenExpiry != null &&
          DateTime.now().isBefore(_tokenExpiry!.subtract(Duration(minutes: 5)))) {
        return _cachedAccessToken!;
      }

      final serviceAccountJson = await rootBundle.loadString('lib/assets/service_account.json');
      final accountCredentials = auth.ServiceAccountCredentials.fromJson(
        json.decode(serviceAccountJson),
      );

      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final authClient = await auth.clientViaServiceAccount(accountCredentials, scopes);

      final accessToken = authClient.credentials.accessToken.data;
      _cachedAccessToken = accessToken;
      _tokenExpiry = authClient.credentials.accessToken.expiry;

      authClient.close();

      print('✅ OAuth2 access token obtained (expires: $_tokenExpiry)');
      return accessToken;

    } catch (e) {
      print('❌ Error getting access token: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 🚀 SEND NOTIFICATION VIA FCM HTTP v1 API
  // ═══════════════════════════════════════════════════════════════

  Future<bool> sendNotification({
    required String token,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      print('🚀 SENDING FCM NOTIFICATION:');
      print('   Token: ${token.substring(0, 20)}...');
      print('   Title: $title');

      final accessToken = await _getAccessToken();
      final serviceAccountJson = await rootBundle.loadString('lib/assets/service_account.json');
      final serviceAccount = json.decode(serviceAccountJson);
      final projectId = serviceAccount['project_id'];

      final url = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({
          'message': {
            'token': token,
            'notification': {
              'title': title,
              'body': body,
            },
            'data': data.map((key, value) => MapEntry(key, value.toString())),
            'android': {
              'priority': data['urgency'] == 'emergency' ? 'high' : 'normal',
              'notification': {
                'sound': 'default',
                'channel_id': 'blood_requests',
              },
            },
            'apns': {
              'payload': {
                'aps': {
                  'sound': 'default',
                  'badge': 1,
                },
              },
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        print('✅ FCM notification sent successfully');
        return true;
      } else {
        print('❌ FCM send failed: ${response.statusCode}');
        print('   Response: ${response.body}');
        return false;
      }

    } catch (e) {
      print('❌ Error sending FCM notification: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 📤 SEND NOTIFICATION WITH FIRESTORE BACKUP
  // ═══════════════════════════════════════════════════════════════

  Future<void> sendNotificationWithBackup({
    required String token,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      final success = await sendNotification(
        token: token,
        title: title,
        body: body,
        data: data,
      );

      if (success) {
        print('✅ Notification delivered immediately');
        return;
      }

      print('⚠️  FCM send failed, queuing for retry...');
      await _firestore.collection('pending_notifications').add({
        'token': token,
        'title': title,
        'body': body,
        'data': data,
        'createdAt': FieldValue.serverTimestamp(),
        'delivered': false,
        'priority': data['urgency'] == 'emergency' ? 'high' : 'normal',
        'retryCount': 0,
        'lastRetry': null,
      });

      print('✅ Notification queued for retry');

    } catch (e) {
      print('❌ Error in sendNotificationWithBackup: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 🚨 EMERGENCY NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════

  Future<void> sendEmergencyNotification({
    required String token,
    required String bloodType,
    required double distance,
    required int units,
    required String requestId,
  }) async {
    final title = '🚨 EMERGENCY: $bloodType Blood Needed!';
    final body = 'EMERGENCY: $bloodType blood needed ${distance.toStringAsFixed(1)}km away. '
        '$units unit(s) required immediately!';

    await sendNotificationWithBackup(
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
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 🔄 RETRY FAILED NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════

  Future<void> retryFailedNotifications() async {
    try {
      print('🔄 Checking for failed notifications...');

      final fiveMinutesAgo = DateTime.now().subtract(Duration(minutes: 5));

      final pendingDocs = await _firestore
          .collection('pending_notifications')
          .where('delivered', isEqualTo: false)
          .where('retryCount', isLessThan: 3)
          .limit(50)
          .get();

      if (pendingDocs.docs.isEmpty) {
        print('✅ No pending notifications');
        return;
      }

      print('🔄 Retrying ${pendingDocs.docs.length} notifications');

      int successCount = 0;
      int failCount = 0;

      for (var doc in pendingDocs.docs) {
        final data = doc.data();

        final lastRetry = (data['lastRetry'] as Timestamp?)?.toDate();
        if (lastRetry != null && lastRetry.isAfter(fiveMinutesAgo)) {
          continue;
        }

        final success = await sendNotification(
          token: data['token'],
          title: data['title'],
          body: data['body'],
          data: Map<String, dynamic>.from(data['data'] ?? {}),
        );

        if (success) {
          await doc.reference.update({
            'delivered': true,
            'deliveredAt': FieldValue.serverTimestamp(),
          });
          successCount++;
        } else {
          await doc.reference.update({
            'retryCount': FieldValue.increment(1),
            'lastRetry': FieldValue.serverTimestamp(),
          });
          failCount++;
        }

        await Future.delayed(Duration(milliseconds: 100));
      }

      print('✅ Retry complete: $successCount delivered, $failCount pending');

    } catch (e) {
      print('❌ Error retrying: $e');
    }
  }

  void startRetryWorker() {
    print('🤖 Starting retry worker...');
    Stream.periodic(Duration(minutes: 5)).listen((_) {
      retryFailedNotifications();
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // 📱 TOKEN MANAGEMENT - PERMANENT SOLUTION
  // ═══════════════════════════════════════════════════════════════

  Future<String?> getCurrentDeviceToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (kDebugMode && token != null) {
        print('📱 Current FCM token: ${token.substring(0, 30)}...');
      }
      return token;
    } catch (e) {
      print('❌ Error getting token: $e');
      return null;
    }
  }

  /// 🔥 PERMANENT SOLUTION: Force refresh and save token
  /// Call this on EVERY app start and login
  Future<void> saveFCMTokenToUser(String userId) async {
    try {
      // 🔥 FORCE DELETE old token and get fresh one
      // This ensures we always have the latest token even after reinstall
      await _firebaseMessaging.deleteToken();
      
      // Small delay to ensure token is deleted
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Get fresh token
      String? token = await _firebaseMessaging.getToken();
      
      if (token != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          'fcmTokenDeviceId': await _getDeviceId(),
        });
        print('✅ FCM token saved for user: $userId');
        print('   Token: ${token.substring(0, 30)}...');
      }
    } catch (e) {
      print('❌ Error saving token: $e');
      // Fallback: try without delete
      await _saveFCMTokenFallback(userId);
    }
  }

  /// Fallback method if deleteToken fails
  Future<void> _saveFCMTokenFallback(String userId) async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ FCM token saved (fallback) for user: $userId');
      }
    } catch (e) {
      print('❌ Error in fallback token save: $e');
    }
  }

  /// Get a unique device identifier
  Future<String> _getDeviceId() async {
    try {
      // Use a combination of factors for device ID
      final token = await _firebaseMessaging.getToken();
      if (token != null && token.length > 20) {
        return token.substring(0, 20); // Use first 20 chars of token as device ID
      }
      return DateTime.now().millisecondsSinceEpoch.toString();
    } catch (e) {
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  /// 🔥 Clear FCM token on logout (important!)
  Future<void> clearFCMToken(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': FieldValue.delete(),
        'fcmTokenUpdatedAt': FieldValue.delete(),
      });
      await _firebaseMessaging.deleteToken();
      print('✅ FCM token cleared for user: $userId');
    } catch (e) {
      print('❌ Error clearing token: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 🔧 INITIALIZATION - ROBUST VERSION
  // ═══════════════════════════════════════════════════════════════

  bool _isInitialized = false;

  Future<void> initializeFCM() async {
    // Prevent double initialization
    if (_isInitialized) {
      print('⚠️ FCM already initialized, skipping...');
      return;
    }

    try {
      print('🔄 INITIALIZING FCM...');

      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        criticalAlert: true,
      );

      print('✅ Notification permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        print('⚠️ Notifications not authorized, some features may not work');
      }

      // 🔥 CRITICAL: Force refresh token on every app start
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await saveFCMTokenToUser(currentUser.uid);
        print('✅ Token force-refreshed for logged-in user: ${currentUser.uid}');
      }

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('📱 Foreground notification:');
        print('   Title: ${message.notification?.title}');
        print('   Body: ${message.notification?.body}');
        
        // You can show a local notification or snackbar here
        _handleForegroundMessage(message);
      });

      // Handle background taps
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        print('👆 Notification tapped (background)');
        _handleNotificationTap(message);
      });

      // Handle terminated state taps
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        print('👆 App opened from notification (terminated)');
        _handleNotificationTap(initialMessage);
      }

      // 🔥 AUTO-REFRESH TOKEN WHEN IT CHANGES (CRITICAL FOR REINSTALLS)
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        print('🔄 FCM token auto-refreshed: ${newToken.substring(0, 30)}...');

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            await _firestore.collection('users').doc(user.uid).update({
              'fcmToken': newToken,
              'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
            });
            print('✅ New token auto-saved to Firestore');
          } catch (e) {
            print('❌ Error auto-saving refreshed token: $e');
          }
        }
      });

      startRetryWorker();
      _isInitialized = true;

      print('✅ FCM initialized successfully');
    } catch (e) {
      print('❌ FCM init failed: $e');
    }
  }

  /// Handle foreground message (show in-app notification)
  void _handleForegroundMessage(RemoteMessage message) {
    // This is handled by DevInboxListener now
    // But you can add additional logic here if needed
    print('📥 Foreground message received: ${message.data}');
  }

  /// Handle notification tap (navigate to relevant screen)
  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];
    final requestId = data['requestId'];
    
    print('🔔 Notification tap data: type=$type, requestId=$requestId');
    
    // Navigation logic can be added here
    // You would need to use a global navigator key or context
  }

  // ═══════════════════════════════════════════════════════════════
  // 🧪 TESTING
  // ═══════════════════════════════════════════════════════════════

  Future<void> sendTestNotification({required String userId}) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final fcmToken = userDoc.data()?['fcmToken'];

      if (fcmToken == null) {
        print('❌ No FCM token');
        return;
      }

      await sendNotification(
        token: fcmToken,
        title: '🧪 TEST: Notifications Working!',
        body: 'Your notifications are working perfectly!',
        data: {
          'type': 'test',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

    } catch (e) {
      print('❌ Test failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 🧹 CLEANUP
  // ═══════════════════════════════════════════════════════════════

  Future<void> cleanupOldNotifications() async {
    try {
      final oneDayAgo = DateTime.now().subtract(Duration(days: 1));

      final oldDocs = await _firestore
          .collection('pending_notifications')
          .where('delivered', isEqualTo: true)
          .where('createdAt', isLessThan: Timestamp.fromDate(oneDayAgo))
          .limit(500)
          .get();

      if (oldDocs.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (var doc in oldDocs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      print('✅ Cleaned ${oldDocs.docs.length} old notifications');
    } catch (e) {
      print('❌ Cleanup error: $e');
    }
  }
}

final fcmService = FCMService();