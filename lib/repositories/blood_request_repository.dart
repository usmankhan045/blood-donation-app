import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/blood_request_model.dart';
import '../services/blood_compatibility_service.dart';
import '../services/request_expiration_service.dart';
import '../services/fulfillment_service.dart';
import '../services/fcm_service.dart';
import '../repositories/chat_repository.dart';

class BloodRequestRepository {
  static final BloodRequestRepository _instance =
      BloodRequestRepository._internal();
  factory BloodRequestRepository() => _instance;
  BloodRequestRepository._internal();

  static BloodRequestRepository get instance => _instance;

  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final RequestExpirationService _expirationService =
      RequestExpirationService();

  // Create a new blood request with 1-HOUR expiration and find eligible donors & blood banks
  // Set requesterType to 'hospital' to skip donor matching (hospitals only need blood banks)
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
    int expirationMinutes = 60, // 1 HOUR default expiration
    String? requesterType, // 'hospital' or 'recipient' - hospitals skip donor matching
  }) async {
    try {
      // Create request document
      final requestRef = _fs.collection('blood_requests').doc();
      final requestId = requestRef.id;

      // Calculate expiration time (1 HOUR from now)
      final now = DateTime.now();
      final expiresAt = now.add(Duration(minutes: expirationMinutes));

      // Create BloodRequest with 1-HOUR expiration
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
        status: 'pending',
        hospital: hospital,
        notes: notes,
        phone: phone,
        neededBy: neededBy,
        searchRadius: searchRadius,
        createdAt: now,
        latitude: location.latitude,
        longitude: location.longitude,
        // 1-HOUR expiration
        expiresAt: expiresAt,
      );

      // Save to Firestore
      await requestRef.set(request.toMap());

      print(
        '🕒 Request created with 1-hour expiration: ${expiresAt.toString()}',
      );

      // 🏥 HOSPITAL REQUESTS: Only find blood banks, skip donors
      // Regular recipient requests find both donors and blood banks
      final isHospitalRequest = requesterType == 'hospital';
      
      if (!isHospitalRequest) {
        // Find eligible donors only for non-hospital requests
        await _findEligibleDonors(request);
        print('👤 Donor matching completed for recipient request');
      } else {
        print('🏥 Hospital request - skipping donor matching');
      }
      
      // Always find eligible blood banks
      await _findEligibleBloodBanks(request);

      // Start expiration timer (1 HOUR)
      _expirationService.startExpirationTimer(requestId, expirationMinutes);

      return requestId;
    } catch (e) {
      print('Error creating request: $e');
      rethrow;
    }
  }

  // SMART ACCEPTANCE: When donor accepts, remove request from all others immediately
  Future<void> acceptRequestByDonor(
    String requestId,
    String donorId,
    String donorName,
  ) async {
    try {
      // First get the current request data
      final requestDoc =
          await _fs.collection('blood_requests').doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Request not found');
      }

      final requestData = requestDoc.data()!;
      final currentStatus = requestData['status'] as String? ?? 'pending';

      // Check if request is still active
      if (currentStatus != 'pending' && currentStatus != 'active') {
        throw Exception('Request is no longer available');
      }

      final potentialDonors = List<String>.from(
        requestData['potentialDonors'] ?? [],
      );
      
      final requesterId = requestData['requesterId'] as String? ?? '';
      final requesterName = requestData['requesterName'] as String? ?? 'Requester';
      final bloodType = requestData['bloodType'] as String? ?? '';
      final units = (requestData['units'] as num?)?.toInt() ?? 1;

      // 🔧 FIX: Use client-side timestamp for immediate query compatibility
      final acceptedAt = DateTime.now();

      // Update request status to accepted immediately
      await _fs.collection('blood_requests').doc(requestId).update({
        'status': 'accepted',
        'acceptedBy': donorId,
        'acceptedByName': donorName,
        'acceptedByType': 'donor',
        'acceptedAt': Timestamp.fromDate(acceptedAt),
        // Clear potential donors and eligible blood banks arrays
        'potentialDonors': [],
        'eligibleBloodBanks': [],
      });

      print('✅ Request $requestId accepted by donor: $donorName');

      // Stop expiration timer since request is accepted
      _expirationService.cancelExpirationTimer(requestId);

      // 🔧 FIX: Initialize chat thread FIRST before any other operations
      try {
        await ChatRepository().initializeChatThread(
          threadId: requestId,
          requesterId: requesterId,
          acceptorId: donorId,
          requesterName: requesterName,
          acceptorName: donorName,
          bloodType: bloodType,
          units: units,
          acceptorType: 'donor',
        );
        
        // Send system message to start the chat
        await ChatRepository().sendSystemMessage(
          threadId: requestId,
          text: '🎉 Request accepted by $donorName! You can now chat to coordinate the donation.',
        );

        print('💬 Chat thread initialized for request $requestId');
      } catch (chatError) {
        print('⚠️ Chat initialization error (non-critical): $chatError');
      }

      // 🔔 Send notification to the requester that their request was accepted
      await _notifyRequester(
        requesterId: requesterId,
        acceptorName: donorName,
        acceptorType: 'donor',
        bloodType: bloodType,
        units: units,
        requestId: requestId,
      );

      print(
        '🔄 Request removed from ${potentialDonors.length - 1} other potential donors',
      );
    } catch (e) {
      print('❌ Error accepting request: $e');
      rethrow;
    }
  }

  // Accept a blood request (by blood bank) - with same smart removal logic
  // Also schedules a fulfillment reminder for inventory deduction
  Future<void> acceptRequestByBloodBank(
    String requestId,
    String bloodBankId,
    String bloodBankName,
  ) async {
    try {
      // First get the current request data
      final requestDoc =
          await _fs.collection('blood_requests').doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Request not found');
      }

      final requestData = requestDoc.data()!;
      final currentStatus = requestData['status'] as String? ?? 'pending';

      // Check if request is still active
      if (currentStatus != 'pending' && currentStatus != 'active') {
        throw Exception('Request is no longer available');
      }

      final potentialDonors = List<String>.from(
        requestData['potentialDonors'] ?? [],
      );
      final bloodType = requestData['bloodType'] as String? ?? '';
      final units = (requestData['units'] as num?)?.toInt() ?? 1;
      final requesterName =
          requestData['requesterName'] as String? ?? 'Requester';
      final requesterId = requestData['requesterId'] as String? ?? '';

      // 🔧 FIX: Use client-side timestamp for immediate query compatibility
      final acceptedAt = DateTime.now();

      // Update request status to accepted immediately
      await _fs.collection('blood_requests').doc(requestId).update({
        'status': 'accepted',
        'acceptedBy': bloodBankId,
        'acceptedByType': 'blood_bank',
        'acceptedBloodBankName': bloodBankName,
        'acceptedAt': Timestamp.fromDate(acceptedAt),
        // Clear potential donors and eligible blood banks arrays
        'potentialDonors': [],
        'eligibleBloodBanks': [],
        // Track fulfillment status
        'fulfillmentStatus': 'pending',
      });

      print('✅ Request $requestId accepted by blood bank: $bloodBankName');

      // Stop expiration timer since request is accepted
      _expirationService.cancelExpirationTimer(requestId);

      // 🔧 FIX: Initialize chat thread FIRST before any other operations
      try {
        await ChatRepository().initializeChatThread(
          threadId: requestId,
          requesterId: requesterId,
          acceptorId: bloodBankId,
          requesterName: requesterName,
          acceptorName: bloodBankName,
          bloodType: bloodType,
          units: units,
          acceptorType: 'blood_bank',
        );
        
        // Send system message to start the chat
        await ChatRepository().sendSystemMessage(
          threadId: requestId,
          text: '🎉 Request accepted by $bloodBankName! You can now chat to coordinate the blood delivery.',
        );

        print('💬 Chat thread initialized for request $requestId');
      } catch (chatError) {
        print('⚠️ Chat initialization error (non-critical): $chatError');
      }

      // 🔔 Schedule fulfillment reminder (30 minutes after acceptance)
      FulfillmentService.instance.scheduleFulfillmentReminder(
        requestId: requestId,
        bloodBankId: bloodBankId,
        bloodType: bloodType,
        units: units,
        requesterName: requesterName,
        reminderDelayMinutes: 30,
      );

      print('⏰ Fulfillment reminder scheduled for 30 minutes');

      // 🔔 Send notification to the requester that their request was accepted
      await _notifyRequester(
        requesterId: requesterId,
        acceptorName: bloodBankName,
        acceptorType: 'blood_bank',
        bloodType: bloodType,
        units: units,
        requestId: requestId,
      );

      print(
        '🔄 Request removed from ${potentialDonors.length} potential donors',
      );
    } catch (e) {
      print('❌ Error accepting request by blood bank: $e');
      rethrow;
    }
  }

  // Expire a request automatically after 1 hour
  Future<void> expireRequest(String requestId) async {
    try {
      final requestDoc =
          await _fs.collection('blood_requests').doc(requestId).get();
      if (!requestDoc.exists) {
        print('Request $requestId not found for expiration');
        return;
      }

      final requestData = requestDoc.data()!;
      final currentStatus = requestData['status'] as String? ?? 'pending';

      // Only expire if still active
      if (currentStatus == 'pending' || currentStatus == 'active') {
        await _fs.collection('blood_requests').doc(requestId).update({
          'status': 'expired',
          'expiredAt': Timestamp.fromDate(DateTime.now()),
          // Clear both potential donors and eligible blood banks arrays
          'potentialDonors': [],
          'eligibleBloodBanks': [],
        });

        print('⏰ Request $requestId expired automatically after 1 hour');
      }
    } catch (e) {
      print('❌ Error expiring request: $e');
    }
  }

  // Find eligible donors and add to potential donors
  Future<void> _findEligibleDonors(BloodRequest request) async {
    try {
      // Get compatible blood types for this recipient
      final compatibleBloodTypes =
          BloodCompatibilityService.getCompatibleDonorTypes(request.bloodType);

      if (compatibleBloodTypes.isEmpty) {
        print('No compatible blood types found for: ${request.bloodType}');
        return;
      }

      print(
        'Searching donors with blood types: ${compatibleBloodTypes.join(', ')}',
      );

      // Get donors with compatible blood types and availability
      final donorsSnapshot =
          await _fs
              .collection('users')
              .where('role', isEqualTo: 'donor')
              .where('bloodType', whereIn: compatibleBloodTypes)
              .where('isAvailable', isEqualTo: true)
              .where('profileCompleted', isEqualTo: true)
              .get();

      if (donorsSnapshot.docs.isEmpty) {
        print('No eligible donors found for blood type: ${request.bloodType}');
        return;
      }

      print('Found ${donorsSnapshot.docs.length} potential donors');

      final eligibleDonors = <String>[];
      final donorDistances = <String, double>{};

      // First pass: Calculate distances for all donors
      for (final donorDoc in donorsSnapshot.docs) {
        final donorData = donorDoc.data();
        final donorId = donorDoc.id;

        if (donorData['location'] is GeoPoint) {
          final donorLocation = donorData['location'] as GeoPoint;
          final distance = _calculateDistance(
            request.latitude,
            request.longitude,
            donorLocation.latitude,
            donorLocation.longitude,
          );

          donorDistances[donorId] = distance;
        }
      }

      // Filter donors by distance and sort by proximity
      final sortedDonors =
          donorsSnapshot.docs.where((doc) {
              final distance = donorDistances[doc.id];
              return distance != null && distance <= request.searchRadius;
            }).toList()
            ..sort((a, b) {
              final distanceA = donorDistances[a.id]!;
              final distanceB = donorDistances[b.id]!;
              return distanceA.compareTo(distanceB);
            });

      print(
        '${sortedDonors.length} donors within ${request.searchRadius}km radius',
      );

      // Add eligible donors to request
      for (final donorDoc in sortedDonors) {
        final donorId = donorDoc.id;
        final donorData = donorDoc.data();
        final distance = donorDistances[donorId]!;

        eligibleDonors.add(donorId);
        print(
          '✅ Eligible donor: ${donorData['fullName']} (${donorData['bloodType']}) - ${distance.toStringAsFixed(1)}km away',
        );
      }

      // Update request with eligible donors
      if (eligibleDonors.isNotEmpty) {
        await _fs.collection('blood_requests').doc(request.id).update({
          'potentialDonors': eligibleDonors,
          'matchingDonorsCount': eligibleDonors.length,
        });
      }

      print(
        '✅ Found ${eligibleDonors.length} eligible donors for request ${request.id}',
      );
    } catch (e) {
      print('❌ Error finding eligible donors: $e');
    }
  }

  // Find eligible blood banks within the search radius
  Future<void> _findEligibleBloodBanks(BloodRequest request) async {
    try {
      // 🔧 ULTRA-LENIENT: Query ALL blood banks first, then filter ONLY by location
      // We want blood banks to see all requests in their area - they decide if they can help
      final bloodBanksSnapshot =
          await _fs
              .collection('users')
              .where('role', isEqualTo: 'blood_bank')
              .get();

      if (bloodBanksSnapshot.docs.isEmpty) {
        print('🏥 No blood banks found in the system');
        return;
      }

      print('🏥 ════════════════════════════════════════════════════════');
      print(
        '🏥 Found ${bloodBanksSnapshot.docs.length} total blood banks in system',
      );

      final eligibleBloodBanks = <String>[];
      final bloodBankDistances = <String, double>{};
      int skippedNoLocation = 0;

      // Calculate distances for all blood banks - ONLY filter by location
      for (final bloodBankDoc in bloodBanksSnapshot.docs) {
        final bloodBankData = bloodBankDoc.data();
        final bloodBankId = bloodBankDoc.id;
        final bloodBankName = bloodBankData['bloodBankName'] as String? ?? 
            bloodBankData['email'] as String? ?? 
            bloodBankId;

        // 🔧 ONLY REQUIREMENT: Must have location
        GeoPoint? location;
        if (bloodBankData['location'] is GeoPoint) {
          location = bloodBankData['location'] as GeoPoint;
        } else {
          // Try latitude/longitude fields
          final lat = bloodBankData['latitude'] as double?;
          final lng = bloodBankData['longitude'] as double?;
          if (lat != null && lng != null) {
            location = GeoPoint(lat, lng);
          }
        }
        
        if (location == null) {
          skippedNoLocation++;
          print('⚠️  Blood bank "$bloodBankName" has no location - SKIPPED');
          continue;
        }

        final distance = _calculateDistance(
          request.latitude,
          request.longitude,
          location.latitude,
          location.longitude,
        );

        bloodBankDistances[bloodBankId] = distance;
      }

      // 🔧 VERY LARGE RADIUS: 5x search radius for blood banks
      final maxDistance = request.searchRadius * 5.0;
      
      // Filter blood banks by distance only
      final sortedBloodBanks =
          bloodBanksSnapshot.docs.where((doc) {
              final distance = bloodBankDistances[doc.id];
              return distance != null && distance <= maxDistance;
            }).toList()
            ..sort((a, b) {
              final distanceA = bloodBankDistances[a.id]!;
              final distanceB = bloodBankDistances[b.id]!;
              return distanceA.compareTo(distanceB);
            });

      print(
        '📍 ${sortedBloodBanks.length} blood banks within ${maxDistance.toStringAsFixed(1)}km radius',
      );

      // Add ALL blood banks within radius to eligibleBloodBanks
      for (final bloodBankDoc in sortedBloodBanks) {
        final bloodBankData = bloodBankDoc.data();
        final bloodBankId = bloodBankDoc.id;
        final bloodBankName =
            bloodBankData['bloodBankName'] as String? ?? 'Blood Bank';
        final distance = bloodBankDistances[bloodBankId]!;

        eligibleBloodBanks.add(bloodBankId);
        print(
          '✅ ADDED: "$bloodBankName" - ${distance.toStringAsFixed(1)}km away',
        );
      }

      // Update request with eligible blood banks
      if (eligibleBloodBanks.isNotEmpty) {
        await _fs.collection('blood_requests').doc(request.id).update({
          'eligibleBloodBanks': eligibleBloodBanks,
        });
      }

      print('🏥 ════════════════════════════════════════════════════════');
      print('📊 Blood Bank Matching Summary:');
      print('   - Total blood banks: ${bloodBanksSnapshot.docs.length}');
      print('   - Skipped (no location): $skippedNoLocation');
      print('   - ✅ ADDED TO REQUEST: ${eligibleBloodBanks.length}');
      print('🏥 ════════════════════════════════════════════════════════');
    } catch (e) {
      print('❌ Error finding eligible blood banks: $e');
    }
  }

  // Calculate distance between two points using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // kilometers

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  // 🔔 Notify requester that their request has been accepted
  Future<void> _notifyRequester({
    required String requesterId,
    required String acceptorName,
    required String acceptorType,
    required String bloodType,
    required int units,
    required String requestId,
  }) async {
    try {
      final requesterDoc = await _fs.collection('users').doc(requesterId).get();
      if (!requesterDoc.exists) return;

      final fcmToken = requesterDoc.data()?['fcmToken'] as String?;
      final requesterRole = requesterDoc.data()?['role'] as String? ?? 'recipient';
      
      final acceptorTypeLabel = acceptorType == 'donor' ? 'Donor' : 'Blood Bank';
      final title = '🎉 Request Accepted!';
      final body = '$acceptorName ($acceptorTypeLabel) has accepted your $bloodType blood request. '
          'You can now chat to coordinate.';

      // Write to in-app notifications
      await _fs
          .collection('user_notifications')
          .doc(requesterId)
          .collection('inbox')
          .add({
        'title': title,
        'body': body,
        'type': 'request_accepted',
        'requestId': requestId,
        'bloodType': bloodType,
        'units': units,
        'acceptorName': acceptorName,
        'acceptorType': acceptorType,
        'targetType': requesterRole,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send FCM push notification
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await FCMService().sendNotification(
          token: fcmToken,
          title: title,
          body: body,
          data: {
            'type': 'request_accepted',
            'requestId': requestId,
            'bloodType': bloodType,
            'units': units.toString(),
            'acceptorName': acceptorName,
            'acceptorType': acceptorType,
            'targetType': requesterRole,
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      print('✅ Requester notified about acceptance: $requesterId');
    } catch (e) {
      print('❌ Error notifying requester: $e');
    }
  }

  // FIXED: Get ALL requests for a recipient (not just active ones)
  Stream<List<BloodRequest>> getRecipientRequests(String recipientId) {
    return _fs
        .collection('blood_requests')
        .where('requesterId', isEqualTo: recipientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                return BloodRequest.fromMap(data, doc.id);
              }).toList(),
        );
  }

  // Get available requests for donors (only pending ones with potential donors)
  Stream<List<BloodRequest>> getAvailableRequestsForDonor(String donorId) {
    return _fs
        .collection('blood_requests')
        .where('status', isEqualTo: 'pending')
        .where('potentialDonors', arrayContains: donorId)
        .orderBy('urgency')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                return BloodRequest.fromMap(data, doc.id);
              }).toList(),
        );
  }

  // Get available requests for blood banks
  Stream<List<BloodRequest>> getAvailableRequestsForBloodBank(
    String bloodBankId,
  ) {
    return _fs
        .collection('blood_requests')
        .where('status', isEqualTo: 'pending')
        .where('eligibleBloodBanks', arrayContains: bloodBankId)
        .orderBy('urgency')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                return BloodRequest.fromMap(data, doc.id);
              }).toList(),
        );
  }

  // Complete a blood request
  Future<void> completeRequest(String requestId) async {
    await _fs.collection('blood_requests').doc(requestId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  // Decline a blood request by blood bank (removes from their available list, goes to their history)
  // This does NOT cancel the request - it just removes this blood bank from the eligible list
  Future<void> declineRequestByBloodBank(String requestId, String bloodBankId) async {
    try {
      final requestDoc = await _fs.collection('blood_requests').doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Request not found');
      }

      final requestData = requestDoc.data()!;
      final eligibleBloodBanks = List<String>.from(requestData['eligibleBloodBanks'] ?? []);
      
      // Remove this blood bank from eligible list
      eligibleBloodBanks.remove(bloodBankId);
      
      // Track declined blood banks
      final declinedBloodBanks = List<String>.from(requestData['declinedBloodBanks'] ?? []);
      if (!declinedBloodBanks.contains(bloodBankId)) {
        declinedBloodBanks.add(bloodBankId);
      }

      await _fs.collection('blood_requests').doc(requestId).update({
        'eligibleBloodBanks': eligibleBloodBanks,
        'declinedBloodBanks': declinedBloodBanks,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Blood bank $bloodBankId declined request $requestId');
    } catch (e) {
      print('❌ Error declining request: $e');
      rethrow;
    }
  }

  // Get declined requests for blood bank history
  Stream<List<BloodRequest>> getDeclinedRequestsForBloodBank(String bloodBankId) {
    return _fs
        .collection('blood_requests')
        .where('declinedBloodBanks', arrayContains: bloodBankId)
        .orderBy('updatedAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                return BloodRequest.fromMap(data, doc.id);
              }).toList(),
        );
  }

  // Cancel a blood request
  Future<void> cancelRequest(String requestId) async {
    await _fs.collection('blood_requests').doc(requestId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  // Update blood request status
  Future<void> updateRequestStatus(String requestId, String status) async {
    await _fs.collection('blood_requests').doc(requestId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get request by ID
  Future<BloodRequest?> getRequestById(String requestId) async {
    try {
      final doc = await _fs.collection('blood_requests').doc(requestId).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        return BloodRequest.fromMap(data, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting request: $e');
      return null;
    }
  }

  // Get statistics for dashboard (UPDATED with expired status)
  Future<Map<String, int>> getRequestStats(
    String userId,
    String userType,
  ) async {
    try {
      QuerySnapshot requestsSnapshot;

      if (userType == 'recipient') {
        requestsSnapshot =
            await _fs
                .collection('blood_requests')
                .where('requesterId', isEqualTo: userId)
                .get();
      } else if (userType == 'donor') {
        requestsSnapshot =
            await _fs
                .collection('blood_requests')
                .where('acceptedBy', isEqualTo: userId)
                .where('acceptedByType', isEqualTo: 'donor')
                .get();
      } else if (userType == 'blood_bank') {
        requestsSnapshot =
            await _fs
                .collection('blood_requests')
                .where('acceptedBy', isEqualTo: userId)
                .where('acceptedByType', isEqualTo: 'blood_bank')
                .get();
      } else {
        return {
          'pending': 0,
          'accepted': 0,
          'completed': 0,
          'expired': 0,
          'total': 0,
        };
      }

      int pending = 0, accepted = 0, completed = 0, expired = 0, total = 0;

      for (final doc in requestsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final request = BloodRequest.fromMap(data, doc.id);
        total++;
        switch (request.status) {
          case 'pending':
            pending++;
            break;
          case 'accepted':
            accepted++;
            break;
          case 'completed':
            completed++;
            break;
          case 'expired':
            expired++;
            break;
        }
      }

      return {
        'pending': pending,
        'accepted': accepted,
        'completed': completed,
        'expired': expired,
        'total': total,
      };
    } catch (e) {
      print('Error getting request stats: $e');
      return {
        'pending': 0,
        'accepted': 0,
        'completed': 0,
        'expired': 0,
        'total': 0,
      };
    }
  }
}
