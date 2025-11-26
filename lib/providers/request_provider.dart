import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/blood_request_model.dart';
import '../services/notification_service.dart';

class RequestProvider with ChangeNotifier {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  List<BloodRequest> _requests = [];
  List<BloodRequest> _acceptedRequests = [];

  List<BloodRequest> get requests => _requests;
  List<BloodRequest> get acceptedRequests => _acceptedRequests;

  // Fetch requests created by the current user (for recipients)
  Future<void> fetchMyRequests() async {
    final uid = _auth.currentUser!.uid;

    try {
      final snapshot = await _fs
          .collection('requests')
          .where('requesterId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();

      _requests = snapshot.docs.map((doc) {
        return BloodRequest.fromDoc(doc);
      }).toList();

      notifyListeners();
    } catch (e) {
      print('Error fetching my requests: $e');
    }
  }

  // Fetch requests accepted by the current user (for donors)
  Future<void> fetchAcceptedRequests() async {
    final uid = _auth.currentUser!.uid;

    try {
      final snapshot = await _fs
          .collection('requests')
          .where('acceptedBy', isEqualTo: uid)
          .orderBy('acceptedAt', descending: true)
          .get();

      _acceptedRequests = snapshot.docs.map((doc) {
        return BloodRequest.fromDoc(doc);
      }).toList();

      notifyListeners();
    } catch (e) {
      print('Error fetching accepted requests: $e');
    }
  }

  // Fetch all active requests for donors to browse
  Stream<QuerySnapshot<Map<String, dynamic>>> getActiveRequestsStream() {
    return _fs
        .collection('requests')
        .where('status', isEqualTo: 'active')
        .orderBy('urgency')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Mark a request as completed
  Future<void> completeRequest(String requestId) async {
    try {
      // Update the status of the request to 'completed'
      await _fs.collection('requests').doc(requestId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Fetch the updated request document to get donor and recipient info
      final requestDoc = await _fs.collection('requests').doc(requestId).get();
      final request = BloodRequest.fromDoc(requestDoc);

      // Get donor and recipient user data to fetch their FCM tokens
      final donorId = request.acceptedBy;
      final recipientId = request.requesterId;

      String? donorToken;
      String? recipientToken;

      // Fetch donor's FCM token
      if (donorId != null && donorId.isNotEmpty) {
        final donorDoc = await _fs.collection('users').doc(donorId).get();
        donorToken = donorDoc.data()?['fcmToken'] as String?;
      }

      // Fetch recipient's FCM token
      if (recipientId.isNotEmpty) {
        final recipientDoc = await _fs.collection('users').doc(recipientId).get();
        recipientToken = recipientDoc.data()?['fcmToken'] as String?;
      }

      // Fetch donor's name for notification
      String donorName = 'a donor';
      if (donorId != null && donorId.isNotEmpty) {
        final donorDoc = await _fs.collection('users').doc(donorId).get();
        donorName = donorDoc.data()?['fullName'] as String? ??
            donorDoc.data()?['name'] as String? ?? 'a donor';
      }

      // Send notifications to both the donor and recipient using the enhanced methods
      if (donorToken != null && donorToken.isNotEmpty) {
        await _notificationService.sendDonorCompletionNotification(
          donorFcmToken: donorToken,
          requestId: requestId,
        );
      }

      if (recipientToken != null && recipientToken.isNotEmpty) {
        await _notificationService.sendDonationCompletedNotification(
          recipientFcmToken: recipientToken,
          requestId: requestId,
          donorName: donorName,
        );
      }

      // Update local state
      await fetchMyRequests();
      await fetchAcceptedRequests();
      notifyListeners();

      print('Request $requestId marked as completed successfully');
    } catch (e) {
      print('Error completing request: $e');
      rethrow;
    }
  }

  // Accept a blood request (for donors)
  Future<void> acceptRequest(String requestId, String donorId) async {
    try {
      await _fs.collection('requests').doc(requestId).update({
        'status': 'accepted',
        'acceptedBy': donorId,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Fetch request to get recipient info
      final requestDoc = await _fs.collection('requests').doc(requestId).get();
      final request = BloodRequest.fromDoc(requestDoc);

      // Fetch recipient's FCM token
      final recipientDoc = await _fs.collection('users').doc(request.requesterId).get();
      final recipientToken = recipientDoc.data()?['fcmToken'] as String?;

      // Fetch donor's name for notification
      final donorDoc = await _fs.collection('users').doc(donorId).get();
      final donorName = donorDoc.data()?['fullName'] as String? ??
          donorDoc.data()?['name'] as String? ?? 'a donor';

      // Send notification to recipient
      if (recipientToken != null && recipientToken.isNotEmpty) {
        await _notificationService.sendRequestAcceptedNotification(
          recipientFcmToken: recipientToken,
          requestId: requestId,
          donorName: donorName,
        );
      }

      await fetchAcceptedRequests();
      notifyListeners();

      print('Request $requestId accepted by donor $donorId');
    } catch (e) {
      print('Error accepting request: $e');
      rethrow;
    }
  }

  // Create a new blood request
  Future<void> createBloodRequest(BloodRequest request) async {
    try {
      await _fs.collection('requests').add(request.toMap());
      await fetchMyRequests();
      notifyListeners();

      print('New blood request created successfully');
    } catch (e) {
      print('Error creating blood request: $e');
      rethrow;
    }
  }

  // Cancel a blood request
  Future<void> cancelRequest(String requestId) async {
    try {
      await _fs.collection('requests').doc(requestId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      await fetchMyRequests();
      notifyListeners();

      print('Request $requestId cancelled successfully');
    } catch (e) {
      print('Error cancelling request: $e');
      rethrow;
    }
  }

  // Get statistics for dashboard
  Future<Map<String, int>> getRequestStats(String userId) async {
    try {
      final myRequestsSnapshot = await _fs
          .collection('requests')
          .where('requesterId', isEqualTo: userId)
          .get();

      final acceptedRequestsSnapshot = await _fs
          .collection('requests')
          .where('acceptedBy', isEqualTo: userId)
          .get();

      int active = 0, accepted = 0, completed = 0, total = 0;

      for (final doc in myRequestsSnapshot.docs) {
        final request = BloodRequest.fromDoc(doc);
        total++;
        switch (request.status) {
          case 'active': active++; break;
          case 'accepted': accepted++; break;
          case 'completed': completed++; break;
        }
      }

      return {
        'active': active,
        'accepted': accepted,
        'completed': completed,
        'total': total,
        'donated': acceptedRequestsSnapshot.docs.length,
      };
    } catch (e) {
      print('Error getting request stats: $e');
      return {'active': 0, 'accepted': 0, 'completed': 0, 'total': 0, 'donated': 0};
    }
  }

  // Clear data when user logs out
  void clearData() {
    _requests.clear();
    _acceptedRequests.clear();
    notifyListeners();
  }
}