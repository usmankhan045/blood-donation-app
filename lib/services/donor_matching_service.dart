import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../models/blood_request_model.dart';
import '../models/donor_model.dart';

class DonorMatchingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<DonorModel>> findMatchingDonors(BloodRequest request) async {
    try {
      print('🔍 Finding matching donors for blood type: ${request.bloodType}');

      // Query users collection with donor role
      final donors = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'donor')
          .where('bloodType', isEqualTo: request.bloodType)
          .where('isAvailable', isEqualTo: true)
          .get();

      print('📊 Found ${donors.docs.length} donors with matching blood type');

      List<DonorModel> matchingDonors = [];

      for (var doc in donors.docs) {
        try {
          var donorData = doc.data();

          // Check if donor has location data as GeoPoint
          if (donorData['location'] == null) {
            print('❌ Donor ${doc.id} missing location data');
            continue;
          }

          // Extract latitude and longitude from GeoPoint
          GeoPoint location = donorData['location'] as GeoPoint;
          double donorLat = location.latitude;
          double donorLng = location.longitude;

          var donor = DonorModel.fromDoc(doc);

          // Calculate distance using the GeoPoint coordinates
          double distance = _calculateDistance(
            request.latitude,
            request.longitude,
            donorLat,
            donorLng,
          );

          // Convert searchRadius to double for comparison
          double searchRadius = request.searchRadius.toDouble();

          if (distance <= searchRadius) {
            matchingDonors.add(donor);
            print('✅ Found matching donor: ${donor.fullName} - ${distance.toStringAsFixed(1)}km away');
          } else {
            print('❌ Donor ${donor.fullName} too far: ${distance.toStringAsFixed(1)}km (max: $searchRadius km)');
          }
        } catch (e) {
          print('❌ Error processing donor ${doc.id}: $e');
        }
      }

      print('🎯 Total matching donors within ${request.searchRadius}km: ${matchingDonors.length}');
      return matchingDonors;
    } catch (e) {
      print('❌ Error finding matching donors: $e');
      return [];
    }
  }

  Future<void> processMatchingDonors(BloodRequest request) async {
    try {
      print('🚀 Starting donor matching process...');
      List<DonorModel> matchingDonors = await findMatchingDonors(request);

      if (matchingDonors.isEmpty) {
        print('❌ No matching donors found');
        return;
      }

      print('📊 Processing ${matchingDonors.length} matching donors...');

      // Update the blood request with potential donors
      await _updateRequestWithPotentialDonors(request.id, matchingDonors);

      print('✅ Successfully processed ${matchingDonors.length} matching donors for request ${request.id}');
    } catch (e) {
      print('❌ Error processing matching donors: $e');
    }
  }

  // Update blood request with potential donors array
  Future<void> _updateRequestWithPotentialDonors(String requestId, List<DonorModel> matchingDonors) async {
    try {
      List<String> donorIds = matchingDonors.map((donor) => donor.userId).toList();

      await _firestore.collection('blood_requests').doc(requestId).update({
        'potentialDonors': donorIds,
        'updatedAt': FieldValue.serverTimestamp(),
        'matchingDonorsCount': matchingDonors.length,
      });

      print('✅ Updated request $requestId with ${donorIds.length} potential donors');
    } catch (e) {
      print('❌ Error updating request with potential donors: $e');
    }
  }

  // Method to get compatible blood types for a recipient blood type
  List<String> getCompatibleBloodTypes(String recipientBloodType) {
    final compatibilityMap = {
      'A+': ['A+', 'A-', 'O+', 'O-'],
      'A-': ['A-', 'O-'],
      'B+': ['B+', 'B-', 'O+', 'O-'],
      'B-': ['B-', 'O-'],
      'AB+': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
      'AB-': ['A-', 'B-', 'AB-', 'O-'],
      'O+': ['O+', 'O-'],
      'O-': ['O-'],
    };

    return compatibilityMap[recipientBloodType] ?? [recipientBloodType];
  }

  // Enhanced donor matching with blood type compatibility
  Future<List<DonorModel>> findCompatibleDonors(BloodRequest request) async {
    try {
      print('🔍 Finding compatible donors for blood type: ${request.bloodType}');

      List<String> compatibleTypes = getCompatibleBloodTypes(request.bloodType);
      print('🎯 Compatible blood types: $compatibleTypes');

      List<DonorModel> allCompatibleDonors = [];

      // Query for each compatible blood type
      for (String bloodType in compatibleTypes) {
        final donors = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'donor')
            .where('bloodType', isEqualTo: bloodType)
            .where('isAvailable', isEqualTo: true)
            .get();

        for (var doc in donors.docs) {
          try {
            var donorData = doc.data();

            if (donorData['location'] == null) {
              continue;
            }

            GeoPoint location = donorData['location'] as GeoPoint;
            double donorLat = location.latitude;
            double donorLng = location.longitude;

            var donor = DonorModel.fromDoc(doc);

            double distance = _calculateDistance(
              request.latitude,
              request.longitude,
              donorLat,
              donorLng,
            );

            double searchRadius = request.searchRadius.toDouble();

            if (distance <= searchRadius) {
              allCompatibleDonors.add(donor);
              print('✅ Found compatible donor: ${donor.fullName} (${donor.bloodType}) - ${distance.toStringAsFixed(1)}km away');
            }
          } catch (e) {
            print('❌ Error processing donor ${doc.id}: $e');
          }
        }
      }

      // Remove duplicates (in case same donor appears multiple times - shouldn't happen)
      allCompatibleDonors = allCompatibleDonors.toSet().toList();

      print('🎯 Total compatible donors within ${request.searchRadius}km: ${allCompatibleDonors.length}');
      return allCompatibleDonors;
    } catch (e) {
      print('❌ Error finding compatible donors: $e');
      return [];
    }
  }

  // Enhanced processing with compatibility matching
  Future<void> processCompatibleDonors(BloodRequest request) async {
    try {
      print('🚀 Starting compatible donor matching process...');
      List<DonorModel> compatibleDonors = await findCompatibleDonors(request);

      if (compatibleDonors.isEmpty) {
        print('❌ No compatible donors found');
        return;
      }

      print('📊 Processing ${compatibleDonors.length} compatible donors...');

      // Update the blood request with potential donors
      await _updateRequestWithPotentialDonors(request.id, compatibleDonors);

      print('✅ Successfully processed ${compatibleDonors.length} compatible donors for request ${request.id}');
    } catch (e) {
      print('❌ Error processing compatible donors: $e');
    }
  }

  // Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // kilometers

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = earthRadius * c;

    return distance;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  // Method to check if donor has complete profile with location
  Future<bool> isDonorProfileComplete(String userId) async {
    try {
      var userDoc = await _firestore.collection('users').doc(userId).get();
      var userData = userDoc.data();

      if (userData == null) return false;

      // Check if profile is completed and has location
      bool profileCompleted = userData['profileCompleted'] ?? false;
      bool hasLocation = userData['location'] != null;

      return profileCompleted && hasLocation;
    } catch (e) {
      print('❌ Error checking donor profile completeness: $e');
      return false;
    }
  }

  // Method to get donor's current requests
  Stream<List<BloodRequest>> getDonorRequestsStream(String donorId) {
    return _firestore
        .collection('blood_requests')
        .where('potentialDonors', arrayContains: donorId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => BloodRequest.fromMap(doc.data(), doc.id))
        .toList());
  }

  // Method to remove donor from potential donors when they accept/decline
  Future<void> removeDonorFromPotentialDonors(String requestId, String donorId) async {
    try {
      await _firestore.collection('blood_requests').doc(requestId).update({
        'potentialDonors': FieldValue.arrayRemove([donorId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Removed donor $donorId from potential donors of request $requestId');
    } catch (e) {
      print('❌ Error removing donor from potential donors: $e');
    }
  }
}