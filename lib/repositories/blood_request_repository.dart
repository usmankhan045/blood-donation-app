import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/blood_request_model.dart';
import '../services/notification_service.dart';
import '../services/blood_compatibility_service.dart';

class BloodRequestRepository {
  static final BloodRequestRepository _instance = BloodRequestRepository._internal();
  factory BloodRequestRepository() => _instance;
  BloodRequestRepository._internal();

  static BloodRequestRepository get instance => _instance;

  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // Create a new blood request and notify eligible donors AND blood banks
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

      // Find and notify eligible donors AND blood banks
      await _findAndNotifyEligibleDonors(request);
      await _findAndNotifyBloodBanks(request);

      return requestId;
    } catch (e) {
      print('Error creating request: $e');
      rethrow;
    }
  }

  // Find eligible donors and send notifications
  Future<void> _findAndNotifyEligibleDonors(BloodRequest request) async {
    try {
      // Get compatible blood types for this recipient
      final compatibleBloodTypes = BloodCompatibilityService.getCompatibleDonorTypes(request.bloodType);

      if (compatibleBloodTypes.isEmpty) {
        print('No compatible blood types found for: ${request.bloodType}');
        return;
      }

      print('Searching donors with blood types: ${compatibleBloodTypes.join(', ')}');

      // Get donors with compatible blood types and availability
      final donorsSnapshot = await _fs
          .collection('users')
          .where('userType', isEqualTo: 'donor')
          .where('bloodGroup', whereIn: compatibleBloodTypes)
          .where('isAvailable', isEqualTo: true)
          .where('profileCompleted', isEqualTo: true)
          .get();

      if (donorsSnapshot.docs.isEmpty) {
        print('No eligible donors found for blood type: ${request.bloodType}');
        return;
      }

      print('Found ${donorsSnapshot.docs.length} potential donors');

      final notifiedDonors = <String>[];
      final donorDistances = <String, double>{};
      int notificationsSent = 0;

      // First pass: Calculate distances for all donors
      for (final donorDoc in donorsSnapshot.docs) {
        final donorData = donorDoc.data() as Map<String, dynamic>;
        final donorId = donorDoc.id;

        if (donorData['location'] is GeoPoint) {
          final donorLocation = donorData['location'] as GeoPoint;
          final distance = _calculateDistance(
            request.location!.latitude,
            request.location!.longitude,
            donorLocation.latitude,
            donorLocation.longitude,
          );

          donorDistances[donorId] = distance;
        }
      }

      // Sort donors by distance and blood type compatibility
      final sortedDonors = donorsSnapshot.docs.where((doc) {
        final distance = donorDistances[doc.id];
        return distance != null && distance <= request.searchRadius;
      }).toList()
        ..sort((a, b) {
          final distanceA = donorDistances[a.id]!;
          final distanceB = donorDistances[b.id]!;

          // Priority: Distance first, then blood type compatibility
          if (distanceA != distanceB) {
            return distanceA.compareTo(distanceB);
          }

          // If same distance, prioritize better blood match
          final priorityA = BloodCompatibilityService.getMatchPriority(
              (a.data() as Map<String, dynamic>)['bloodGroup'],
              request.bloodType
          );
          final priorityB = BloodCompatibilityService.getMatchPriority(
              (b.data() as Map<String, dynamic>)['bloodGroup'],
              request.bloodType
          );

          return priorityB.compareTo(priorityA);
        });

      print('${sortedDonors.length} donors within ${request.searchRadius}km radius');

      // Notify sorted donors
      for (final donorDoc in sortedDonors) {
        if (notificationsSent >= _getDonorNotificationLimit(request.urgency)) break;

        final donorData = donorDoc.data() as Map<String, dynamic>;
        final donorId = donorDoc.id;
        final donorFcmToken = donorData['fcmToken'] as String?;

        if (donorFcmToken != null && donorFcmToken.isNotEmpty) {
          final distance = donorDistances[donorId]!;

          // Send notification to donor
          await _notificationService.sendBloodRequestNotification(
            donorFcmToken: donorFcmToken,
            request: request,
            distance: distance,
          );

          notifiedDonors.add(donorId);
          notificationsSent++;

          print('Notified donor $donorId (${donorData['bloodGroup']}) - ${distance.toStringAsFixed(1)}km away');
        }
      }

      // Update request with notified donors
      if (notifiedDonors.isNotEmpty) {
        await _fs.collection('requests').doc(request.id).update({
          'notifiedDonors': FieldValue.arrayUnion(notifiedDonors),
        });
      }

      print('✅ Sent $notificationsSent notifications to compatible donors for request ${request.id}');

    } catch (e) {
      print('❌ Error notifying donors: $e');
    }
  }

  // Find and notify blood banks within the search radius
  Future<void> _findAndNotifyBloodBanks(BloodRequest request) async {
    try {
      // Get blood banks with the required blood type in inventory
      final bloodBanksSnapshot = await _fs
          .collection('users')
          .where('userType', isEqualTo: 'blood_bank')
          .where('profileCompleted', isEqualTo: true)
          .where('isActive', isEqualTo: true)
          .get();

      if (bloodBanksSnapshot.docs.isEmpty) {
        print('No blood banks found in the system');
        return;
      }

      print('Found ${bloodBanksSnapshot.docs.length} blood banks');

      final notifiedBloodBanks = <String>[];
      final bloodBankDistances = <String, double>{};
      int notificationsSent = 0;

      // Calculate distances for all blood banks
      for (final bloodBankDoc in bloodBanksSnapshot.docs) {
        final bloodBankData = bloodBankDoc.data() as Map<String, dynamic>;
        final bloodBankId = bloodBankDoc.id;

        if (bloodBankData['location'] is GeoPoint) {
          final bloodBankLocation = bloodBankData['location'] as GeoPoint;
          final distance = _calculateDistance(
            request.location!.latitude,
            request.location!.longitude,
            bloodBankLocation.latitude,
            bloodBankLocation.longitude,
          );

          bloodBankDistances[bloodBankId] = distance;
        }
      }

      // Sort blood banks by distance
      final sortedBloodBanks = bloodBanksSnapshot.docs.where((doc) {
        final distance = bloodBankDistances[doc.id];
        return distance != null && distance <= request.searchRadius * 2; // Blood banks can have larger radius
      }).toList()
        ..sort((a, b) {
          final distanceA = bloodBankDistances[a.id]!;
          final distanceB = bloodBankDistances[b.id]!;
          return distanceA.compareTo(distanceB);
        });

      print('${sortedBloodBanks.length} blood banks within ${request.searchRadius * 2}km radius');

      // Notify sorted blood banks
      for (final bloodBankDoc in sortedBloodBanks) {
        if (notificationsSent >= _getBloodBankNotificationLimit(request.urgency)) break;

        final bloodBankData = bloodBankDoc.data() as Map<String, dynamic>;
        final bloodBankId = bloodBankDoc.id;
        final bloodBankFcmToken = bloodBankData['fcmToken'] as String?;
        final bloodBankName = bloodBankData['bloodBankName'] as String? ?? 'Blood Bank';

        if (bloodBankFcmToken != null && bloodBankFcmToken.isNotEmpty) {
          final distance = bloodBankDistances[bloodBankId]!;

          // Check if blood bank has the required blood type in stock
          final hasBloodType = await _checkBloodBankInventory(bloodBankId, request.bloodType, request.units);

          if (hasBloodType) {
            // Send notification to blood bank
            await _notificationService.sendBloodRequestToBloodBank(
              bloodBankFcmToken: bloodBankFcmToken,
              request: request,
              bloodBankName: bloodBankName,
              distance: distance,
            );

            notifiedBloodBanks.add(bloodBankId);
            notificationsSent++;

            print('Notified blood bank $bloodBankId - ${distance.toStringAsFixed(1)}km away - Has inventory');
          } else {
            print('Blood bank $bloodBankId does not have sufficient ${request.bloodType} inventory');
          }
        }
      }

      // Update request with notified blood banks
      if (notifiedBloodBanks.isNotEmpty) {
        await _fs.collection('requests').doc(request.id).update({
          'notifiedBloodBanks': FieldValue.arrayUnion(notifiedBloodBanks),
        });
      }

      print('✅ Sent $notificationsSent notifications to blood banks for request ${request.id}');

    } catch (e) {
      print('❌ Error notifying blood banks: $e');
    }
  }

  // Check if blood bank has sufficient inventory
  Future<bool> _checkBloodBankInventory(String bloodBankId, String bloodType, int requiredUnits) async {
    try {
      final inventoryDoc = await _fs
          .collection('blood_banks')
          .doc(bloodBankId)
          .collection('inventory')
          .doc(bloodType)
          .get();

      if (inventoryDoc.exists) {
        final inventoryData = inventoryDoc.data() as Map<String, dynamic>?;
        final availableUnits = (inventoryData?['availableUnits'] as num?)?.toInt() ?? 0;
        return availableUnits >= requiredUnits;
      }

      return false;
    } catch (e) {
      print('Error checking blood bank inventory: $e');
      return false;
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

  // Helper method to get donor notification limits based on urgency
  int _getDonorNotificationLimit(String urgency) {
    switch (urgency) {
      case 'emergency':
        return 50; // Notify more donors for emergencies
      case 'high':
        return 30;
      case 'normal':
        return 20;
      case 'low':
        return 10;
      default:
        return 15;
    }
  }

  // Helper method to get blood bank notification limits based on urgency
  int _getBloodBankNotificationLimit(String urgency) {
    switch (urgency) {
      case 'emergency':
        return 10; // Notify all blood banks for emergencies
      case 'high':
        return 8;
      case 'normal':
        return 5;
      case 'low':
        return 3;
      default:
        return 5;
    }
  }

  // Get active requests for a recipient
  Stream<List<BloodRequest>> getRecipientRequests(String recipientId) {
    return _fs
        .collection('requests')
        .where('requesterId', isEqualTo: recipientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => BloodRequest.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>))
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
        .map((doc) => BloodRequest.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList());
  }

  // Get available requests for blood banks
  Stream<List<BloodRequest>> getAvailableRequestsForBloodBank(String bloodBankId) {
    return _fs
        .collection('requests')
        .where('status', isEqualTo: 'active')
        .where('notifiedBloodBanks', arrayContains: bloodBankId)
        .orderBy('urgency')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => BloodRequest.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList());
  }

  // Accept a blood request (by donor)
  Future<void> acceptRequestByDonor(String requestId, String donorId, String donorName) async {
    await _fs.collection('requests').doc(requestId).update({
      'status': 'accepted',
      'acceptedBy': donorId,
      'acceptedByType': 'donor',
      'acceptedDonorName': donorName,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  // Accept a blood request (by blood bank)
  Future<void> acceptRequestByBloodBank(String requestId, String bloodBankId, String bloodBankName) async {
    await _fs.collection('requests'). doc(requestId).update({
      'status': 'accepted',
      'acceptedBy': bloodBankId,
      'acceptedByType': 'blood_bank',
      'acceptedBloodBankName': bloodBankName,
      'acceptedAt': FieldValue.serverTimestamp(),
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

  // Update blood request status
  Future<void> updateRequestStatus(String requestId, String status) async {
    await _fs.collection('requests').doc(requestId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get request by ID
  Future<BloodRequest?> getRequestById(String requestId) async {
    try {
      final doc = await _fs.collection('requests').doc(requestId).get();
      if (doc.exists) {
        return BloodRequest.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>);
      }
      return null;
    } catch (e) {
      print('Error getting request: $e');
      return null;
    }
  }

  // Get statistics for dashboard
  Future<Map<String, int>> getRequestStats(String userId, String userType) async {
    try {
      QuerySnapshot requestsSnapshot;

      if (userType == 'recipient') {
        requestsSnapshot = await _fs
            .collection('requests')
            .where('requesterId', isEqualTo: userId)
            .get();
      } else if (userType == 'donor') {
        requestsSnapshot = await _fs
            .collection('requests')
            .where('acceptedBy', isEqualTo: userId)
            .where('acceptedByType', isEqualTo: 'donor')
            .get();
      } else if (userType == 'blood_bank') {
        requestsSnapshot = await _fs
            .collection('requests')
            .where('acceptedBy', isEqualTo: userId)
            .where('acceptedByType', isEqualTo: 'blood_bank')
            .get();
      } else {
        return {'active': 0, 'accepted': 0, 'completed': 0, 'total': 0};
      }

      int active = 0, accepted = 0, completed = 0, total = 0;

      for (final doc in requestsSnapshot.docs) {
        final request = BloodRequest.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>);
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
      };
    } catch (e) {
      print('Error getting request stats: $e');
      return {'active': 0, 'accepted': 0, 'completed': 0, 'total': 0};
    }
  }
}