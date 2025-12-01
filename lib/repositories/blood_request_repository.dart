import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/blood_request_model.dart';
import '../services/blood_compatibility_service.dart';
import '../services/request_expiration_service.dart';

class BloodRequestRepository {
  static final BloodRequestRepository _instance = BloodRequestRepository._internal();
  factory BloodRequestRepository() => _instance;
  BloodRequestRepository._internal();

  static BloodRequestRepository get instance => _instance;

  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RequestExpirationService _expirationService = RequestExpirationService();

  // Create a new blood request with 1-HOUR expiration and find eligible donors & blood banks
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

      print('🕒 Request created with 1-hour expiration: ${expiresAt.toString()}');

      // Find eligible donors AND blood banks
      await _findEligibleDonors(request);
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
  Future<void> acceptRequestByDonor(String requestId, String donorId, String donorName) async {
    try {
      // First get the current request data
      final requestDoc = await _fs.collection('blood_requests').doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Request not found');
      }

      final requestData = requestDoc.data()!;
      final currentStatus = requestData['status'] as String? ?? 'pending';

      // Check if request is still active
      if (currentStatus != 'pending' && currentStatus != 'active') {
        throw Exception('Request is no longer available');
      }

      final potentialDonors = List<String>.from(requestData['potentialDonors'] ?? []);

      // Update request status to accepted immediately
      await _fs.collection('blood_requests').doc(requestId).update({
        'status': 'accepted',
        'acceptedBy': donorId,
        'acceptedByName': donorName,
        'acceptedByType': 'donor',
        'acceptedAt': FieldValue.serverTimestamp(),
        // Clear potential donors array
        'potentialDonors': [],
      });

      print('✅ Request $requestId accepted by donor: $donorName');

      // Stop expiration timer since request is accepted
      _expirationService.cancelExpirationTimer(requestId);

      print('🔄 Request removed from ${potentialDonors.length - 1} other potential donors');

    } catch (e) {
      print('❌ Error accepting request: $e');
      rethrow;
    }
  }

  // Accept a blood request (by blood bank) - with same smart removal logic
  Future<void> acceptRequestByBloodBank(String requestId, String bloodBankId, String bloodBankName) async {
    try {
      // First get the current request data
      final requestDoc = await _fs.collection('blood_requests').doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Request not found');
      }

      final requestData = requestDoc.data()!;
      final currentStatus = requestData['status'] as String? ?? 'pending';

      // Check if request is still active
      if (currentStatus != 'pending' && currentStatus != 'active') {
        throw Exception('Request is no longer available');
      }

      final potentialDonors = List<String>.from(requestData['potentialDonors'] ?? []);

      // Update request status to accepted immediately
      await _fs.collection('blood_requests').doc(requestId).update({
        'status': 'accepted',
        'acceptedBy': bloodBankId,
        'acceptedByType': 'blood_bank',
        'acceptedBloodBankName': bloodBankName,
        'acceptedAt': FieldValue.serverTimestamp(),
        // Clear potential donors array
        'potentialDonors': [],
      });

      print('✅ Request $requestId accepted by blood bank: $bloodBankName');

      // Stop expiration timer since request is accepted
      _expirationService.cancelExpirationTimer(requestId);

      print('🔄 Request removed from ${potentialDonors.length} potential donors');

    } catch (e) {
      print('❌ Error accepting request by blood bank: $e');
      rethrow;
    }
  }

  // Expire a request automatically after 1 hour
  Future<void> expireRequest(String requestId) async {
    try {
      final requestDoc = await _fs.collection('blood_requests').doc(requestId).get();
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
          'expiredAt': FieldValue.serverTimestamp(),
          // Clear potential donors array
          'potentialDonors': [],
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
      final compatibleBloodTypes = BloodCompatibilityService.getCompatibleDonorTypes(request.bloodType);

      if (compatibleBloodTypes.isEmpty) {
        print('No compatible blood types found for: ${request.bloodType}');
        return;
      }

      print('Searching donors with blood types: ${compatibleBloodTypes.join(', ')}');

      // Get donors with compatible blood types and availability
      final donorsSnapshot = await _fs
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
        final donorData = donorDoc.data() as Map<String, dynamic>;
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
      final sortedDonors = donorsSnapshot.docs.where((doc) {
        final distance = donorDistances[doc.id];
        return distance != null && distance <= request.searchRadius;
      }).toList()
        ..sort((a, b) {
          final distanceA = donorDistances[a.id]!;
          final distanceB = donorDistances[b.id]!;
          return distanceA.compareTo(distanceB);
        });

      print('${sortedDonors.length} donors within ${request.searchRadius}km radius');

      // Add eligible donors to request
      for (final donorDoc in sortedDonors) {
        final donorId = donorDoc.id;
        final donorData = donorDoc.data() as Map<String, dynamic>;
        final distance = donorDistances[donorId]!;

        eligibleDonors.add(donorId);
        print('✅ Eligible donor: ${donorData['fullName']} (${donorData['bloodType']}) - ${distance.toStringAsFixed(1)}km away');
      }

      // Update request with eligible donors
      if (eligibleDonors.isNotEmpty) {
        await _fs.collection('blood_requests').doc(request.id).update({
          'potentialDonors': eligibleDonors,
          'matchingDonorsCount': eligibleDonors.length,
        });
      }

      print('✅ Found ${eligibleDonors.length} eligible donors for request ${request.id}');

    } catch (e) {
      print('❌ Error finding eligible donors: $e');
    }
  }

  // Find eligible blood banks within the search radius
  Future<void> _findEligibleBloodBanks(BloodRequest request) async {
    try {
      // 🔧 FIXED: Query blood banks with completed profiles (removed isActive filter for broader matching)
      // We'll check isActive/isVerified after fetching to allow either field
      final bloodBanksSnapshot = await _fs
          .collection('users')
          .where('role', isEqualTo: 'blood_bank')
          .where('profileCompleted', isEqualTo: true)
          .get();

      if (bloodBanksSnapshot.docs.isEmpty) {
        print('No blood banks found in the system');
        return;
      }

      print('Found ${bloodBanksSnapshot.docs.length} blood banks with completed profiles');

      final eligibleBloodBanks = <String>[];
      final bloodBankDistances = <String, double>{};

      // Calculate distances for all blood banks
      for (final bloodBankDoc in bloodBanksSnapshot.docs) {
        final bloodBankData = bloodBankDoc.data() as Map<String, dynamic>;
        final bloodBankId = bloodBankDoc.id;

        // 🔧 FIXED: Check for either isActive OR isVerified (supports both field names)
        final isActive = bloodBankData['isActive'] as bool? ?? false;
        final isVerified = bloodBankData['isVerified'] as bool? ?? false;
        
        if (!isActive && !isVerified) {
          print('❌ Blood bank ${bloodBankData['bloodBankName'] ?? bloodBankId} is not active/verified');
          continue;
        }

        if (bloodBankData['location'] is GeoPoint) {
          final bloodBankLocation = bloodBankData['location'] as GeoPoint;
          final distance = _calculateDistance(
            request.latitude,
            request.longitude,
            bloodBankLocation.latitude,
            bloodBankLocation.longitude,
          );

          bloodBankDistances[bloodBankId] = distance;
        }
      }

      // Filter blood banks by distance
      final sortedBloodBanks = bloodBanksSnapshot.docs.where((doc) {
        final distance = bloodBankDistances[doc.id];
        return distance != null && distance <= request.searchRadius * 2;
      }).toList()
        ..sort((a, b) {
          final distanceA = bloodBankDistances[a.id]!;
          final distanceB = bloodBankDistances[b.id]!;
          return distanceA.compareTo(distanceB);
        });

      print('${sortedBloodBanks.length} blood banks within ${request.searchRadius * 2}km radius');

      // Check inventory for eligible blood banks
      for (final bloodBankDoc in sortedBloodBanks) {
        final bloodBankData = bloodBankDoc.data() as Map<String, dynamic>;
        final bloodBankId = bloodBankDoc.id;
        final bloodBankName = bloodBankData['bloodBankName'] as String? ?? 'Blood Bank';
        final distance = bloodBankDistances[bloodBankId]!;

        // Check if blood bank has the required blood type in stock
        final hasBloodType = await _checkBloodBankInventory(bloodBankId, request.bloodType, request.units);

        if (hasBloodType) {
          eligibleBloodBanks.add(bloodBankId);
          print('✅ Eligible blood bank: $bloodBankName - ${distance.toStringAsFixed(1)}km away - Has inventory');
        } else {
          print('❌ Blood bank $bloodBankName does not have sufficient ${request.bloodType} inventory');
        }
      }

      // Update request with eligible blood banks
      if (eligibleBloodBanks.isNotEmpty) {
        await _fs.collection('blood_requests').doc(request.id).update({
          'eligibleBloodBanks': eligibleBloodBanks,
        });
      }

      print('✅ Found ${eligibleBloodBanks.length} eligible blood banks for request ${request.id}');

    } catch (e) {
      print('❌ Error finding eligible blood banks: $e');
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

  // FIXED: Get ALL requests for a recipient (not just active ones)
  Stream<List<BloodRequest>> getRecipientRequests(String recipientId) {
    return _fs
        .collection('blood_requests')
        .where('requesterId', isEqualTo: recipientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      return BloodRequest.fromMap(data, doc.id);
    })
        .toList());
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
        .map((snapshot) => snapshot.docs
        .map((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      return BloodRequest.fromMap(data, doc.id);
    })
        .toList());
  }

  // Get available requests for blood banks
  Stream<List<BloodRequest>> getAvailableRequestsForBloodBank(String bloodBankId) {
    return _fs
        .collection('blood_requests')
        .where('status', isEqualTo: 'pending')
        .where('eligibleBloodBanks', arrayContains: bloodBankId)
        .orderBy('urgency')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      return BloodRequest.fromMap(data, doc.id);
    })
        .toList());
  }

  // Complete a blood request
  Future<void> completeRequest(String requestId) async {
    await _fs.collection('blood_requests').doc(requestId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
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
        final data = doc.data() as Map<String, dynamic>? ?? {};
        return BloodRequest.fromMap(data, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting request: $e');
      return null;
    }
  }

  // Get statistics for dashboard (UPDATED with expired status)
  Future<Map<String, int>> getRequestStats(String userId, String userType) async {
    try {
      QuerySnapshot requestsSnapshot;

      if (userType == 'recipient') {
        requestsSnapshot = await _fs
            .collection('blood_requests')
            .where('requesterId', isEqualTo: userId)
            .get();
      } else if (userType == 'donor') {
        requestsSnapshot = await _fs
            .collection('blood_requests')
            .where('acceptedBy', isEqualTo: userId)
            .where('acceptedByType', isEqualTo: 'donor')
            .get();
      } else if (userType == 'blood_bank') {
        requestsSnapshot = await _fs
            .collection('blood_requests')
            .where('acceptedBy', isEqualTo: userId)
            .where('acceptedByType', isEqualTo: 'blood_bank')
            .get();
      } else {
        return {'pending': 0, 'accepted': 0, 'completed': 0, 'expired': 0, 'total': 0};
      }

      int pending = 0, accepted = 0, completed = 0, expired = 0, total = 0;

      for (final doc in requestsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final request = BloodRequest.fromMap(data, doc.id);
        total++;
        switch (request.status) {
          case 'pending': pending++; break;
          case 'accepted': accepted++; break;
          case 'completed': completed++; break;
          case 'expired': expired++; break;
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
      return {'pending': 0, 'accepted': 0, 'completed': 0, 'expired': 0, 'total': 0};
    }
  }
}