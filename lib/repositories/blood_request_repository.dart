import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/blood_request_model.dart';
import '../services/notification_service.dart';

class BloodRequestRepository {
  static final BloodRequestRepository _instance = BloodRequestRepository._internal();
  factory BloodRequestRepository() => _instance;
  BloodRequestRepository._internal();

  static BloodRequestRepository get instance => _instance;

  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // Create a new blood request and notify eligible donors
  Future<String> createRequest({
    required String requesterId,
    required String requesterName,
    required String city,
    required String bloodType,
    required String urgency,
    required int units,
    required GeoPoint location,
    required String address,
    String? hospital,
    String? notes,
    String? phone,
    DateTime? neededBy,
    int searchRadius = 10,
  }) async {
    try {
      // Create request document
      final requestRef = _fs.collection('requests').doc();
      final requestId = requestRef.id;

      final request = BloodRequest(
        id: requestId,
        requesterId: requesterId,
        requesterName: requesterName,
        bloodType: bloodType,
        units: units,
        urgency: urgency,
        city: city,
        address: address,
        location: location,
        status: 'active',
        hospital: hospital,
        notes: notes,
        phone: phone,
        neededBy: neededBy,
        searchRadius: searchRadius,
        createdAt: DateTime.now(),
      );

      // Save to Firestore
      await requestRef.set(request.toMap());

      // Find and notify eligible donors
      await _findAndNotifyEligibleDonors(request);

      return requestId;
    } catch (e) {
      print('Error creating request: $e');
      rethrow;
    }
  }

  // Find eligible donors and send notifications
  Future<void> _findAndNotifyEligibleDonors(BloodRequest request) async {
    try {
      // Get donors with matching blood type and availability
      final donorsSnapshot = await _fs
          .collection('users')
          .where('userType', isEqualTo: 'donor')
          .where('bloodGroup', isEqualTo: request.bloodType)
          .where('isAvailable', isEqualTo: true)
          .where('profileCompleted', isEqualTo: true)
          .get();

      if (donorsSnapshot.docs.isEmpty) {
        print('No eligible donors found for blood type: ${request.bloodType}');
        return;
      }

      final notifiedDonors = <String>[];
      int notificationsSent = 0;

      for (final donorDoc in donorsSnapshot.docs) {
        final donorData = donorDoc.data();
        final donorId = donorDoc.id;

        // Check if donor has location data
        if (donorData['location'] is GeoPoint) {
          final donorLocation = donorData['location'] as GeoPoint;
          final distance = _calculateDistance(
            request.location!.latitude,
            request.location!.longitude,
            donorLocation.latitude,
            donorLocation.longitude,
          );

          // Check if donor is within search radius
          if (distance <= request.searchRadius) {
            final donorFcmToken = donorData['fcmToken'] as String?;

            if (donorFcmToken != null && donorFcmToken.isNotEmpty) {
              // Send notification to donor
              await _notificationService.sendBloodRequestNotification(
                donorFcmToken: donorFcmToken,
                request: request,
                distance: distance,
              );

              notifiedDonors.add(donorId);
              notificationsSent++;

              // Limit notifications for urgent requests to avoid spam
              if (request.isUrgent && notificationsSent >= 20) break;
              if (!request.isUrgent && notificationsSent >= 10) break;
            }
          }
        }
      }

      // Update request with notified donors
      if (notifiedDonors.isNotEmpty) {
        await _fs.collection('requests').doc(request.id).update({
          'notifiedDonors': notifiedDonors,
        });
      }

      print('Sent $notificationsSent notifications for request ${request.id}');
    } catch (e) {
      print('Error notifying donors: $e');
    }
  }

  // Calculate distance between two points using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // kilometers

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  // Get active requests for a recipient
  Stream<List<BloodRequest>> getRecipientRequests(String recipientId) {
    return _fs
        .collection('requests')
        .where('requesterId', isEqualTo: recipientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => BloodRequest.fromDoc(doc))
        .toList());
  }

  // Get available requests for donors
  Stream<List<BloodRequest>> getAvailableRequestsForDonor(String donorId) {
    return _fs
        .collection('requests')
        .where('status', isEqualTo: 'active')
        .where('notifiedDonors', arrayContains: donorId)
        .orderBy('urgency')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => BloodRequest.fromDoc(doc))
        .toList());
  }

  // Accept a blood request
  Future<void> acceptRequest(String requestId, String donorId, String donorName) async {
    await _fs.collection('requests').doc(requestId).update({
      'status': 'accepted',
      'acceptedBy': donorId,
      'acceptedAt': FieldValue.serverTimestamp(),
      'acceptedDonorName': donorName,
    });
  }

  // Complete a blood request
  Future<void> completeRequest(String requestId) async {
    await _fs.collection('requests').doc(requestId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  // Cancel a blood request
  Future<void> cancelRequest(String requestId) async {
    await _fs.collection('requests').doc(requestId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }
}