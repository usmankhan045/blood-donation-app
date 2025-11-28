// import 'dart:async';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import '../models/blood_request_model.dart';
// import 'donor_matching_service.dart';
//
// class NotificationService {
//   final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
//   final FirebaseFirestore _fs = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//
//   // ✅ FIXED: Remove direct instantiation, will be injected via ServiceLocator
//   late DonorMatchingService _donorMatchingService;
//
//   static final GlobalKey<NavigatorState> navigatorKey =
//       GlobalKey<NavigatorState>();
//
//   // ✅ ADDED: Setter for dependency injection
//   void setDonorMatchingService(DonorMatchingService donorMatchingService) {
//     _donorMatchingService = donorMatchingService;
//   }
//
//   // Initialize FCM
//   Future<void> initializeFCM() async {
//     try {
//       print('🔄 Initializing FCM...');
//
//       // Request permission
//       NotificationSettings settings = await _firebaseMessaging
//           .requestPermission(
//             alert: true,
//             badge: true,
//             sound: true,
//             provisional: false,
//           );
//
//       print('✅ Notification permission: ${settings.authorizationStatus}');
//
//       // Get and save FCM token
//       String? fcmToken = await _firebaseMessaging.getToken();
//       print("🎯 FCM Token: $fcmToken");
//
//       if (fcmToken != null) {
//         await _saveFcmToken(fcmToken);
//       }
//
//       // Listen for token refresh
//       _firebaseMessaging.onTokenRefresh.listen(_saveFcmToken);
//
//       // Handle different message types
//       FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
//       FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
//
//       // Get initial message when app is terminated
//       RemoteMessage? initialMessage =
//           await _firebaseMessaging.getInitialMessage();
//       if (initialMessage != null) {
//         _handleMessageOpenedApp(initialMessage);
//       }
//
//       print('✅ FCM initialization completed successfully');
//     } catch (e) {
//       print('❌ FCM initialization error: $e');
//     }
//   }
//
//   // Save FCM token to Firestore
//   Future<void> _saveFcmToken(String token) async {
//     final user = _auth.currentUser;
//     if (user != null) {
//       try {
//         await _fs.collection('users').doc(user.uid).update({
//           'fcmToken': token,
//           'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
//         });
//         print('✅ FCM token saved for user: ${user.uid}');
//       } catch (e) {
//         print('❌ Error saving FCM token: $e');
//         await _fs.collection('users').doc(user.uid).set({
//           'fcmToken': token,
//           'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
//         }, SetOptions(merge: true));
//       }
//     }
//   }
//
//   // Handle foreground messages
//   Future<void> _handleForegroundMessage(RemoteMessage message) async {
//     print('📱 Foreground message: ${message.data}');
//
//     final data = message.data;
//     final notification = message.notification;
//
//     // Show in-app notification (SnackBar)
//     if (navigatorKey.currentContext != null) {
//       _showInAppNotification(
//         title: notification?.title ?? data['title'] ?? 'New Notification',
//         body: notification?.body ?? data['body'] ?? '',
//         requestId: data['requestId'],
//         type: data['type'],
//       );
//     }
//   }
//
//   // Handle when user taps on notification
//   Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
//     print('👆 Message opened: ${message.data}');
//
//     final data = message.data;
//     final requestId = data['requestId'];
//     final type = data['type'];
//
//     if (requestId != null && navigatorKey.currentContext != null) {
//       _navigateToRequest(requestId, type);
//     }
//   }
//
//   // Show in-app notification with action
//   void _showInAppNotification({
//     required String title,
//     required String body,
//     String? requestId,
//     String? type,
//   }) {
//     final context = navigatorKey.currentContext;
//     if (context == null) return;
//
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               title,
//               style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
//             ),
//             if (body.isNotEmpty)
//               Text(body, style: const TextStyle(fontSize: 12)),
//           ],
//         ),
//         backgroundColor: Colors.blueGrey[800],
//         behavior: SnackBarBehavior.floating,
//         margin: const EdgeInsets.all(16),
//         duration: const Duration(seconds: 6),
//         action:
//             requestId != null
//                 ? SnackBarAction(
//                   label: 'View',
//                   textColor: Colors.white,
//                   onPressed: () => _navigateToRequest(requestId, type),
//                 )
//                 : null,
//       ),
//     );
//   }
//
//   // Navigate to appropriate screen based on notification type
//   void _navigateToRequest(String requestId, String? type) {
//     final context = navigatorKey.currentContext;
//     if (context == null) return;
//
//     if (type == 'blood_request') {
//       Navigator.pushNamed(
//         context,
//         '/donor_requests',
//         arguments: {'requestId': requestId},
//       );
//     } else if (type == 'request_accepted') {
//       Navigator.pushNamed(
//         context,
//         '/recipient_requests',
//         arguments: {'requestId': requestId},
//       );
//     } else if (type == 'donation_completed') {
//       Navigator.pushNamed(
//         context,
//         '/completed_requests',
//         arguments: {'requestId': requestId},
//       );
//     } else if (type == 'blood_request_blood_bank') {
//       Navigator.pushNamed(
//         context,
//         '/blood_bank_requests',
//         arguments: {'requestId': requestId},
//       );
//     } else if (type == 'request_expired') {
//       Navigator.pushNamed(
//         context,
//         '/recipient_requests',
//         arguments: {'requestId': requestId},
//       );
//     } else if (type == 'request_accepted_by_other') {
//       Navigator.pushNamed(context, '/donor_requests');
//     }
//   }
//
//   // NEW: Find matching donors and send notifications
//   Future<void> notifyMatchingDonors(BloodRequest request) async {
//     await _donorMatchingService.notifyMatchingDonors(request);
//   }
//
//   // Send blood request notification to donors
//   Future<void> sendBloodRequestNotification({
//     required String donorFcmToken,
//     required BloodRequest request,
//     required double distance,
//   }) async {
//     try {
//       final title = _getRequestNotificationTitle(request.urgency);
//       final body = _getRequestNotificationBody(request, distance);
//
//       // Store notification in user's inbox
//       await _storeNotificationInInbox(
//         userId: _getUserIdFromToken(donorFcmToken),
//         title: title,
//         body: body,
//         type: 'blood_request',
//         requestId: request.id,
//       );
//
//       // Send REAL push notification using FCM
//       await _sendRealFCMNotification(
//         token: donorFcmToken,
//         title: title,
//         body: body,
//         data: {
//           'type': 'blood_request',
//           'requestId': request.id,
//           'bloodType': request.bloodType,
//           'urgency': request.urgency,
//           'distance': distance.toStringAsFixed(1),
//           'expiresIn': '1 hour', // NEW: 1-hour timer info
//         },
//       );
//
//       print('✅ REAL Blood request notification sent to donor');
//     } catch (e) {
//       print('❌ Error sending blood request notification: $e');
//     }
//   }
//
//   // Send blood request to blood bank
//   Future<void> sendBloodRequestToBloodBank({
//     required String bloodBankFcmToken,
//     required BloodRequest request,
//     required String bloodBankName,
//     required double distance,
//   }) async {
//     try {
//       final title = '🩸 Blood Request - ${request.bloodType}';
//       final body =
//           '${request.units} unit(s) needed ${distance.toStringAsFixed(1)}km away. '
//           'Urgency: ${request.urgency.toUpperCase()} - Expires in 1 hour';
//
//       // Store notification in blood bank's inbox
//       await _storeNotificationInInbox(
//         userId: _getUserIdFromToken(bloodBankFcmToken),
//         title: title,
//         body: body,
//         type: 'blood_request_blood_bank',
//         requestId: request.id,
//       );
//
//       // Send REAL push notification using FCM
//       await _sendRealFCMNotification(
//         token: bloodBankFcmToken,
//         title: title,
//         body: body,
//         data: {
//           'type': 'blood_request_blood_bank',
//           'requestId': request.id,
//           'bloodType': request.bloodType,
//           'units': request.units.toString(),
//           'urgency': request.urgency,
//           'distance': distance.toStringAsFixed(1),
//           'bloodBankName': bloodBankName,
//           'expiresIn': '1 hour', // NEW: 1-hour timer info
//         },
//       );
//
//       print(
//         '✅ REAL Blood request notification sent to blood bank: $bloodBankName',
//       );
//     } catch (e) {
//       print('❌ Error sending blood bank notification: $e');
//     }
//   }
//
//   // NEW: Send notification when request is accepted by blood bank
//   Future<void> sendRequestAcceptedByBloodBankNotification({
//     required String recipientFcmToken,
//     required String requestId,
//     required String bloodBankName,
//   }) async {
//     try {
//       const title = 'Request Accepted! 🏥';
//       final body =
//           '$bloodBankName has accepted your blood request and will provide the needed blood.';
//
//       // Store in recipient's inbox
//       await _storeNotificationInInbox(
//         userId: _getUserIdFromToken(recipientFcmToken),
//         title: title,
//         body: body,
//         type: 'request_accepted',
//         requestId: requestId,
//       );
//
//       // Send REAL push notification using FCM
//       await _sendRealFCMNotification(
//         token: recipientFcmToken,
//         title: title,
//         body: body,
//         data: {
//           'type': 'request_accepted',
//           'requestId': requestId,
//           'acceptedBy': 'blood_bank',
//           'bloodBankName': bloodBankName,
//         },
//       );
//
//       print('✅ REAL Blood bank acceptance notification sent to recipient');
//     } catch (e) {
//       print('❌ Error sending blood bank acceptance notification: $e');
//     }
//   }
//
//   // NEW: Send notification to other donors when request is accepted by someone else
//   Future<void> sendRequestAcceptedByOtherNotification({
//     required String donorFcmToken,
//     required String bloodType,
//     required int units,
//     required String city,
//     required String acceptedDonorName,
//   }) async {
//     try {
//       const title = 'Request Fulfilled ✅';
//       final body =
//           '$bloodType request in $city was accepted by $acceptedDonorName. '
//           'Thank you for your willingness to help!';
//
//       // Store in donor's inbox
//       await _storeNotificationInInbox(
//         userId: _getUserIdFromToken(donorFcmToken),
//         title: title,
//         body: body,
//         type: 'request_accepted_by_other',
//         requestId: '', // No specific request since it's removed
//       );
//
//       // Send REAL push notification using FCM
//       await _sendRealFCMNotification(
//         token: donorFcmToken,
//         title: title,
//         body: body,
//         data: {
//           'type': 'request_accepted_by_other',
//           'bloodType': bloodType,
//           'units': units.toString(),
//           'city': city,
//           'acceptedDonorName': acceptedDonorName,
//         },
//       );
//
//       print('✅ REAL Request accepted by other notification sent to donor');
//     } catch (e) {
//       print('❌ Error sending request accepted by other notification: $e');
//     }
//   }
//
//   // NEW: Send notification when request expires after 1 hour
//   Future<void> sendRequestExpiredNotification({
//     required String recipientFcmToken,
//     required String requestId,
//   }) async {
//     try {
//       const title = 'Request Expired ⏰';
//       final body =
//           'Your blood request has expired after 1 hour. No donors were available at this time. '
//           'You can create a new request if needed.';
//
//       // Store in recipient's inbox
//       await _storeNotificationInInbox(
//         userId: _getUserIdFromToken(recipientFcmToken),
//         title: title,
//         body: body,
//         type: 'request_expired',
//         requestId: requestId,
//       );
//
//       // Send REAL push notification using FCM
//       await _sendRealFCMNotification(
//         token: recipientFcmToken,
//         title: title,
//         body: body,
//         data: {'type': 'request_expired', 'requestId': requestId},
//       );
//
//       print('✅ REAL Request expired notification sent to recipient');
//     } catch (e) {
//       print('❌ Error sending request expired notification: $e');
//     }
//   }
//
//   // NEW: Send notification for expiring soon warning (15 minutes left)
//   Future<void> sendRequestExpiringSoonNotification({
//     required String recipientFcmToken,
//     required String requestId,
//     required String bloodType,
//     required int minutesLeft,
//   }) async {
//     try {
//       const title = 'Request Expiring Soon ⚠️';
//       final body =
//           'Your $bloodType blood request will expire in $minutesLeft minutes. '
//           'Consider extending or creating a new request.';
//
//       // Store in recipient's inbox
//       await _storeNotificationInInbox(
//         userId: _getUserIdFromToken(recipientFcmToken),
//         title: title,
//         body: body,
//         type: 'request_expiring_soon',
//         requestId: requestId,
//       );
//
//       // Send REAL push notification using FCM
//       await _sendRealFCMNotification(
//         token: recipientFcmToken,
//         title: title,
//         body: body,
//         data: {
//           'type': 'request_expiring_soon',
//           'requestId': requestId,
//           'bloodType': bloodType,
//           'minutesLeft': minutesLeft.toString(),
//         },
//       );
//
//       print('✅ REAL Request expiring soon notification sent to recipient');
//     } catch (e) {
//       print('❌ Error sending expiring soon notification: $e');
//     }
//   }
//
//   // Send notification to donor when they complete a donation
//   Future<void> sendDonorCompletionNotification({
//     required String donorFcmToken,
//     required String requestId,
//   }) async {
//     try {
//       const title = 'Donation Recorded! 🙏';
//       final body =
//           'Thank you for your life-saving donation! Your contribution has been recorded.';
//
//       // Store in donor's inbox
//       await _storeNotificationInInbox(
//         userId: _getUserIdFromToken(donorFcmToken),
//         title: title,
//         body: body,
//         type: 'donation_recorded',
//         requestId: requestId,
//       );
//
//       // Send REAL push notification using FCM
//       await _sendRealFCMNotification(
//         token: donorFcmToken,
//         title: title,
//         body: body,
//         data: {'type': 'donation_recorded', 'requestId': requestId},
//       );
//
//       print('✅ REAL Donor completion notification sent');
//     } catch (e) {
//       print('❌ Error sending donor completion notification: $e');
//     }
//   }
//
//   // Send donation completed notification to recipient
//   Future<void> sendDonationCompletedNotification({
//     required String recipientFcmToken,
//     required String requestId,
//     required String donorName,
//   }) async {
//     try {
//       const title = 'Donation Completed! ✅';
//       final body =
//           'Blood donation from $donorName has been completed successfully. Thank you for saving a life!';
//
//       // Store in recipient's inbox
//       await _storeNotificationInInbox(
//         userId: _getUserIdFromToken(recipientFcmToken),
//         title: title,
//         body: body,
//         type: 'donation_completed',
//         requestId: requestId,
//       );
//
//       // Send REAL push notification using FCM
//       await _sendRealFCMNotification(
//         token: recipientFcmToken,
//         title: title,
//         body: body,
//         data: {
//           'type': 'donation_completed',
//           'requestId': requestId,
//           'donorName': donorName,
//         },
//       );
//
//       print('✅ REAL Donation completed notification sent');
//     } catch (e) {
//       print('❌ Error sending donation completed notification: $e');
//     }
//   }
//
//   // Send notification when request is accepted
//   Future<void> sendRequestAcceptedNotification({
//     required String recipientFcmToken,
//     required String requestId,
//     required String donorName,
//   }) async {
//     try {
//       const title = 'Request Accepted! 🎉';
//       final body = '$donorName has accepted your blood request';
//
//       // Store in recipient's inbox
//       await _storeNotificationInInbox(
//         userId: _getUserIdFromToken(recipientFcmToken),
//         title: title,
//         body: body,
//         type: 'request_accepted',
//         requestId: requestId,
//       );
//
//       // Send REAL push notification using FCM
//       await _sendRealFCMNotification(
//         token: recipientFcmToken,
//         title: title,
//         body: body,
//         data: {
//           'type': 'request_accepted',
//           'requestId': requestId,
//           'donorName': donorName,
//         },
//       );
//
//       print('✅ REAL Request accepted notification sent to recipient');
//     } catch (e) {
//       print('❌ Error sending request accepted notification: $e');
//     }
//   }
//
//   // REAL FCM notification method - sends actual push notifications via HTTP API
//   Future<void> _sendRealFCMNotification({
//     required String token,
//     required String title,
//     required String body,
//     required Map<String, dynamic> data,
//   }) async {
//     try {
//       print('🚀 SENDING REAL FCM NOTIFICATION:');
//       print(
//         '   Token: ${token.length > 20 ? '${token.substring(0, 20)}...' : token}',
//       );
//       print('   Title: $title');
//       print('   Body: $body');
//       print('   Data: $data');
//
//       // Send via HTTP API (correct method)
//       await _sendViaHttpAPI(token: token, title: title, body: body, data: data);
//
//       print(
//         '✅ REAL FCM notification sent successfully to token: ${token.length > 10 ? token.substring(0, 10) : token}...',
//       );
//     } catch (e, stackTrace) {
//       print('❌ FCM Error: $e');
//       print('Stack trace: $stackTrace');
//     }
//   }
//
//   // Helper method to send notification via HTTP API
//   Future<void> _sendViaHttpAPI({
//     required String token,
//     required String title,
//     required String body,
//     required Map<String, dynamic> data,
//   }) async {
//     try {
//       // ✅ FIXED: Replace with your actual Firebase Server Key
//       final String serverKey =
//           "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDrzFtT3GQefJui\nwZcTEGD1l/msCtxFvAJS3gICDIeWHNaTJgssOYCcKZSqYYnvW4B0XScCNecySHFI\ncLaWTF6s99qK8ZyDB0meaLJj/+8KL5vphDRJGHSi8RchKZLCZF4ZKdy8b1nK8lF5\nZCPeVWPP6UV1vTJIt8cBz0Dk3RMEyo67InGbFbtixrQkgnHd0ZTNjG6yJ2DzJYcc\nprEZA3zbn55vVx/WWqt+Hqi+SvX++4vcz+idILxHPQCQTSsI+sqSkvKWLNj7JUFv\nPFqjO424YnBXosJB5pa8/fXTPRHIRwRBEcDbv7vpySj2Yi8IxqkM+ijKQV0by9Zf\nkpcvHNnDAgMBAAECggEAIWTwPDi2vzCTlCHJpQwJR07uL6TcHE4roBPMAgFHRIWy\nB+X36Bv+sF8dLGIi+FCjqRc2OpRquU7UKFe6LCAFuoZhn5LnQRFLplEajpoE/xLO\nCGzOQNnjTt5JEcvC+p/fSb4JgnBcrabSzhfWEptSRvQ4/5s7X1wTpZh2DtOWaXOG\n2hkuAa+kEFFiL3qFfmnoSHK4xK+FzSQo2XqMSuMunGCTnDJCuk5nPK9FDqttCcIY\nDpc0SOrsBhC4LIjTdCAQlUUBGJM/U2FMhh/5Hdv5AJVgD5IHK/sNaRw6aBPYsqXt\nuITLGKOUpdwGYo1dBiHfZf9yBYVShTnH71EX4UpnFQKBgQD33TM4cI71MzwvWhCs\n+86RyoaFJZ24/tIs3Xdx8QJ7uJo6JG3gm2MozngGQ/CNJN/q9KAV7BBqBVxxWogG\njaDQNc4J3CdqXLpoTrN+dmcMal1oSOQCD6nneMt/ZziGhm9vNV3UdUyNnqaJ0d3o\nBO0KHan/vBXjTAaKoOAzXzCC1QKBgQDzicSUOyBpUbBRxLOikqzzh1UmEN3utfpm\n0f3B79kik/oY7oeVBYKB7NrI+9YNhhOUa9BBdONyishnrar+znf0HqONe+lUO71/\n3+kgozxv25YbhJz/cOH/tD6AZepK1xVecvfv1gNiU/99U0ZTokFCJ0Ra12ILkOdQ\nQ/+nnIDGNwKBgHgyf5U+GEVV/DimP3Hzhn/yq3tD+5FrmTaCi1ro2iBvK/NIGTST\nhemS/mdjaPK5UBDbYgpfeLJBOUwK7+3lnnd5sBnd9gtBPnA4whhwiJZfuj5JIrDR\nMb57OIvm3WV3KfDO+1p9K4t9xRsOd8L9KIoASqEmb6LTClUNoMuovJilAoGBAPCd\nFvmVCUrFCL1g6FIhNHtPJFN9qqekaAeaRWqM/CzrotdrI82aKf0P9IFKP4wRAdtM\nQe/J+sY6VBILRbyGZYFtnA23dSph87IZmY1DefzSKRZ7CVpfPwqSHIZjKv5STqyI\nTmpJOgK2FuDNm9gZoPwpK6HM1vOycLee10HUoG41AoGBAIkOme1JaprFArKK7aHo\n7gQsaL8/hTPyjnvM+BL17l48xA9qylM6zyzB5EWYU8vMgEL49KL/dNCRLAMjdT6N\ni4jeYriDQV/ahJz5mRI1VqD3cJHS1HNP78V3EWWqUeZgKKol8i9bNHk5D6WVpYHu\nITrG731TAn0vGG09NQwYqsVb\n-----END PRIVATE KEY-----\n"; // Use your actual key
//
//       final Map<String, dynamic> notificationPayload = {
//         'to': token,
//         'notification': {
//           'title': title,
//           'body': body,
//           'sound': 'default',
//           'badge': '1',
//         },
//         'data': data,
//         'android': {
//           'priority': 'high',
//           'notification': {
//             'sound': 'default',
//             'channel_id': 'high_importance_channel',
//           },
//         },
//         'apns': {
//           'payload': {
//             'aps': {
//               'alert': {'title': title, 'body': body},
//               'sound': 'default',
//               'badge': 1,
//             },
//           },
//         },
//       };
//
//       final response = await http.post(
//         Uri.parse('https://fcm.googleapis.com/fcm/send'),
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'key=$serverKey',
//         },
//         body: jsonEncode(notificationPayload),
//       );
//
//       if (response.statusCode == 200) {
//         print('✅ FCM HTTP API call successful');
//         final responseData = jsonDecode(response.body);
//         if (responseData['success'] == 1) {
//           print('✅ FCM notification delivered successfully');
//         } else {
//           print('❌ FCM notification delivery failed: ${responseData}');
//         }
//       } else {
//         print(
//           '❌ FCM HTTP API error: ${response.statusCode} - ${response.body}',
//         );
//       }
//     } catch (e) {
//       print('❌ Error in HTTP API call: $e');
//       rethrow;
//     }
//   }
//
//   // Store notification in user's inbox for persistence
//   Future<void> _storeNotificationInInbox({
//     required String userId,
//     required String title,
//     required String body,
//     required String type,
//     required String requestId,
//   }) async {
//     try {
//       await _fs
//           .collection('user_notifications')
//           .doc(userId)
//           .collection('inbox')
//           .add({
//             'title': title,
//             'body': body,
//             'type': type,
//             'requestId': requestId,
//             'read': false,
//             'createdAt': FieldValue.serverTimestamp(),
//           });
//       print('✅ Notification stored in inbox for user: $userId');
//     } catch (e) {
//       print('❌ Error storing notification in inbox: $e');
//     }
//   }
//
//   // Helper methods for notification content
//   String _getRequestNotificationTitle(String urgency) {
//     switch (urgency) {
//       case 'emergency':
//         return '🚨 EMERGENCY Blood Request';
//       case 'high':
//         return '⚠️ Urgent Blood Needed';
//       case 'normal':
//         return '🩸 Blood Donation Request';
//       case 'low':
//         return 'Blood Donation Opportunity';
//       default:
//         return 'Blood Donation Request';
//     }
//   }
//
//   String _getRequestNotificationBody(BloodRequest request, double distance) {
//     final distanceText =
//         distance < 1
//             ? '${(distance * 1000).round()}m away'
//             : '${distance.toStringAsFixed(1)}km away';
//
//     final urgencyText = request.urgency == 'emergency' ? 'URGENT: ' : '';
//
//     return '$urgencyText${request.bloodType} blood needed $distanceText. '
//         '${request.units} unit(s) required. Expires in 1 hour.';
//   }
//
//   // Helper method to extract user ID from token context
//   String _getUserIdFromToken(String token) {
//     final currentUser = _auth.currentUser;
//     return currentUser?.uid ?? 'unknown_user';
//   }
//
//   // Get user's unread notifications
//   Stream<List<Map<String, dynamic>>> getUserNotifications(String userId) {
//     return _fs
//         .collection('user_notifications')
//         .doc(userId)
//         .collection('inbox')
//         .where('read', isEqualTo: false)
//         .orderBy('createdAt', descending: true)
//         .snapshots()
//         .map(
//           (snapshot) =>
//               snapshot.docs.map((doc) {
//                 final data = doc.data();
//                 return {
//                   'id': doc.id,
//                   'title': data['title'] ?? '',
//                   'body': data['body'] ?? '',
//                   'type': data['type'] ?? '',
//                   'requestId': data['requestId'] ?? '',
//                   'createdAt': data['createdAt'],
//                   'read': data['read'] ?? false,
//                 };
//               }).toList(),
//         );
//   }
//
//   // Mark notification as read
//   Future<void> markNotificationAsRead(
//     String userId,
//     String notificationId,
//   ) async {
//     try {
//       await _fs
//           .collection('user_notifications')
//           .doc(userId)
//           .collection('inbox')
//           .doc(notificationId)
//           .update({'read': true});
//       print('✅ Notification marked as read: $notificationId');
//     } catch (e) {
//       print('❌ Error marking notification as read: $e');
//     }
//   }
//
//   // Mark all notifications as read
//   Future<void> markAllNotificationsAsRead(String userId) async {
//     try {
//       final notifications =
//           await _fs
//               .collection('user_notifications')
//               .doc(userId)
//               .collection('inbox')
//               .where('read', isEqualTo: false)
//               .get();
//
//       final batch = _fs.batch();
//       for (final doc in notifications.docs) {
//         batch.update(doc.reference, {'read': true});
//       }
//       await batch.commit();
//       print('✅ All notifications marked as read for user: $userId');
//     } catch (e) {
//       print('❌ Error marking all notifications as read: $e');
//     }
//   }
//
//   // Get current user's FCM token
//   Future<String?> getCurrentUserToken() async {
//     return await _firebaseMessaging.getToken();
//   }
//
//   // Subscribe to topics
//   Future<void> subscribeToTopic(String topic) async {
//     await _firebaseMessaging.subscribeToTopic(topic);
//     print('✅ Subscribed to topic: $topic');
//   }
//
//   // Unsubscribe from topics
//   Future<void> unsubscribeFromTopic(String topic) async {
//     await _firebaseMessaging.unsubscribeFromTopic(topic);
//     print('✅ Unsubscribed from topic: $topic');
//   }
// }
