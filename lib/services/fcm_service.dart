import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'navigation_service.dart';

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
          DateTime.now().isBefore(
            _tokenExpiry!.subtract(Duration(minutes: 5)),
          )) {
        return _cachedAccessToken!;
      }

      final serviceAccountJson = await rootBundle.loadString(
        'lib/assets/service_account.json',
      );
      final accountCredentials = auth.ServiceAccountCredentials.fromJson(
        json.decode(serviceAccountJson),
      );

      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final authClient = await auth.clientViaServiceAccount(
        accountCredentials,
        scopes,
      );

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
      final serviceAccountJson = await rootBundle.loadString(
        'lib/assets/service_account.json',
      );
      final serviceAccount = json.decode(serviceAccountJson);
      final projectId = serviceAccount['project_id'];

      final url =
          'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({
          'message': {
            'token': token,
            'notification': {'title': title, 'body': body},
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
                'aps': {'sound': 'default', 'badge': 1},
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
    final body =
        'EMERGENCY: $bloodType blood needed ${distance.toStringAsFixed(1)}km away. '
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

      final pendingDocs =
          await _firestore
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
        return token.substring(
          0,
          20,
        ); // Use first 20 chars of token as device ID
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

      NotificationSettings settings = await _firebaseMessaging
          .requestPermission(
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
      RemoteMessage? initialMessage =
          await _firebaseMessaging.getInitialMessage();
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
    final type = data['type'] as String?;
    final requestId = data['requestId'] as String?;
    final targetType = data['targetType'] as String?;
    final threadId = data['threadId'] as String?;
    final senderName = data['senderName'] as String?;
    final bloodType = data['bloodType'] as String?;

    print(
      '🔔 Notification tap data: type=$type, requestId=$requestId, targetType=$targetType, threadId=$threadId',
    );

    // Wait a bit for the app to be ready
    Future.delayed(const Duration(milliseconds: 500), () {
      if (type == 'blood_request' || type == 'emergency_blood_request') {
        // Navigate based on who the notification was for
        if (targetType == 'donor') {
          _navigateTo('/donor_requests');
        } else if (targetType == 'blood_bank') {
          _navigateTo('/blood_bank_dashboard');
        } else if (targetType == 'hospital') {
          _navigateTo('/hospital/my_requests');
        } else if (targetType == 'recipient') {
          _navigateTo('/recipient/my_requests');
        } else {
          // Default: try to determine from current user
          _navigateBasedOnUserRole();
        }
      } else if (type == 'account_approved' || type == 'account_rejected') {
        // Navigate to login screen
        _navigateTo('/select_role');
      } else if (type == 'chat_message') {
        // Navigate to specific chat
        if (threadId != null && threadId.isNotEmpty) {
          _navigateToChatScreen(threadId, senderName, bloodType);
        } else {
          _navigateTo('/chats');
        }
      } else if (type == 'fulfillment_reminder') {
        _navigateTo('/blood_bank_dashboard');
      } else if (type == 'request_accepted') {
        // Navigate based on who the notification was for
        if (targetType == 'recipient') {
          _navigateTo('/recipient/my_requests');
        } else if (targetType == 'hospital') {
          _navigateTo('/hospital/my_requests');
        } else {
          _navigateBasedOnUserRole();
        }
      } else {
        // Default navigation based on user role
        _navigateBasedOnUserRole();
      }
    });
  }

  /// Navigate to specific chat screen
  void _navigateToChatScreen(
    String threadId,
    String? senderName,
    String? bloodType,
  ) async {
    try {
      final navigator = NavigationService.instance.navigator;
      if (navigator == null) {
        print('⚠️ Navigator not ready for chat navigation');
        _pendingNavigation = '/chats';
        return;
      }

      // Get additional info from thread if needed
      String title = senderName ?? 'Chat';
      String subtitle =
          bloodType != null ? '$bloodType Blood Request' : 'Blood Request';
      String? otherUserId;

      try {
        final threadDoc =
            await _firestore.collection('chat_threads').doc(threadId).get();
        if (threadDoc.exists) {
          final data = threadDoc.data()!;
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;
          final participants = List<String>.from(data['participants'] ?? []);

          // Get the other user's ID
          otherUserId = participants.firstWhere(
            (id) => id != currentUserId,
            orElse: () => '',
          );

          // Get names
          if (otherUserId.isNotEmpty) {
            final otherUserDoc =
                await _firestore.collection('users').doc(otherUserId).get();
            if (otherUserDoc.exists) {
              title =
                  otherUserDoc.data()?['fullName'] ??
                  otherUserDoc.data()?['hospitalName'] ??
                  otherUserDoc.data()?['bloodBankName'] ??
                  senderName ??
                  'User';
            }
          }

          final bt = data['bloodType'] as String?;
          final units = data['units'];
          if (bt != null) {
            subtitle =
                '$bt Blood Request${units != null ? ' - $units unit(s)' : ''}';
          }
        }
      } catch (e) {
        print('⚠️ Could not fetch thread details: $e');
      }

      // Import and navigate to ChatScreen
      // Using pushNamed with arguments
      navigator.pushNamed('/chats');

      // Then navigate to specific chat after a short delay
      Future.delayed(const Duration(milliseconds: 300), () {
        try {
          // Navigate using dynamic import approach
          _openChatDirectly(threadId, title, subtitle, otherUserId);
        } catch (e) {
          print('⚠️ Could not open specific chat: $e');
        }
      });

      print('✅ Navigated to chat: $threadId');
    } catch (e) {
      print('❌ Error navigating to chat: $e');
      _navigateTo('/chats');
    }
  }

  /// Open chat directly using navigator
  void _openChatDirectly(
    String threadId,
    String title,
    String subtitle,
    String? otherUserId,
  ) {
    try {
      final navigator = NavigationService.instance.navigator;
      if (navigator == null) return;

      // We need to push the ChatScreen widget directly
      // This requires importing ChatScreen, but to avoid circular imports,
      // we'll use a callback approach
      if (_chatNavigationCallback != null) {
        _chatNavigationCallback!(threadId, title, subtitle, otherUserId);
      }
    } catch (e) {
      print('❌ Error opening chat directly: $e');
    }
  }

  // Callback for chat navigation (set from main.dart or chat_list_screen)
  static Function(
    String threadId,
    String title,
    String subtitle,
    String? otherUserId,
  )?
  _chatNavigationCallback;

  static void setChatNavigationCallback(
    Function(String, String, String, String?) callback,
  ) {
    _chatNavigationCallback = callback;
  }

  /// Navigate to a specific route using the global navigator
  void _navigateTo(String route) {
    try {
      final navigator = NavigationService.instance.navigator;
      if (navigator != null) {
        navigator.pushNamed(route);
        print('✅ Navigated to: $route');
      } else {
        print('⚠️ Navigator not ready, queuing navigation to: $route');
        // Queue for later navigation
        _pendingNavigation = route;
      }
    } catch (e) {
      print('❌ Navigation error: $e');
    }
  }

  String? _pendingNavigation;

  /// Check and execute pending navigation
  void checkPendingNavigation() {
    if (_pendingNavigation != null) {
      final route = _pendingNavigation!;
      _pendingNavigation = null;
      Future.delayed(const Duration(milliseconds: 500), () {
        _navigateTo(route);
      });
    }
  }

  /// Navigate based on current user role
  void _navigateBasedOnUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final role = userDoc.data()?['role'] as String?;

      switch (role) {
        case 'donor':
          _navigateTo('/donor_requests');
          break;
        case 'recipient':
          _navigateTo('/recipient/my_requests');
          break;
        case 'blood_bank':
          _navigateTo('/blood_bank_dashboard');
          break;
        case 'hospital':
          _navigateTo('/hospital/my_requests');
          break;
        case 'admin':
          _navigateTo('/admin_dashboard');
          break;
      }
    } catch (e) {
      print('❌ Error navigating by role: $e');
    }
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
        data: {'type': 'test', 'timestamp': DateTime.now().toIso8601String()},
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

      final oldDocs =
          await _firestore
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
