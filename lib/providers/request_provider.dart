import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/blood_request_model.dart';
import '../services/notification_service.dart';

class RequestProvider with ChangeNotifier {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // A list to store the requests for the current user
  List<BloodRequest> _requests = [];

  List<BloodRequest> get requests => _requests;

  // Fetch the requests for the current user (donor/recipient)
  Future<void> fetchRequests() async {
    final uid = _auth.currentUser!.uid;

    try {
      // Query requests for the current user (recipient or donor)
      final snapshot = await _fs
          .collection('requests')
          .where('requesterId', isEqualTo: uid)
          .get();

      _requests = snapshot.docs.map((doc) {
        return BloodRequest.fromDoc(doc);
      }).toList();

      notifyListeners(); // Notify listeners when data is fetched
    } catch (e) {
      print('Error fetching requests: $e');
    }
  }

  // Mark a request as completed
  Future<void> completeRequest(String requestId) async {
    try {
      // Update the status of the request to 'Completed'
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
          donorName: 'the donor', // You might want to fetch donor's actual name
        );
      }

      // Update local state
      await fetchRequests(); // Refresh the requests list
      notifyListeners(); // Notify listeners to update the UI after request completion

      print('Request $requestId marked as completed successfully');
    } catch (e) {
      print('Error completing request: $e');
      rethrow;
    }
  }

  // Additional method: Accept a blood request (for donors)
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
      final donorName = donorDoc.data()?['name'] as String? ?? 'a donor';

      // Send notification to recipient
      if (recipientToken != null && recipientToken.isNotEmpty) {
        await _notificationService.sendRequestAcceptedNotification(
          recipientFcmToken: recipientToken,
          requestId: requestId,
          donorName: donorName,
        );
      }

      await fetchRequests(); // Refresh requests
      notifyListeners();

      print('Request $requestId accepted by donor $donorId');
    } catch (e) {
      print('Error accepting request: $e');
      rethrow;
    }
  }

  // Additional method: Create a new blood request
  Future<void> createBloodRequest(BloodRequest request) async {
    try {
      await _fs.collection('requests').add(request.toMap());
      await fetchRequests(); // Refresh requests
      notifyListeners();

      print('New blood request created successfully');
    } catch (e) {
      print('Error creating blood request: $e');
      rethrow;
    }
  }

  // Additional method: Cancel a blood request
  Future<void> cancelRequest(String requestId) async {
    try {
      await _fs.collection('requests').doc(requestId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      await fetchRequests(); // Refresh requests
      notifyListeners();

      print('Request $requestId cancelled successfully');
    } catch (e) {
      print('Error cancelling request: $e');
      rethrow;
    }
  }
}