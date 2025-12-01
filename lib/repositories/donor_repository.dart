import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/donor_model.dart';
import 'dart:math';

class DonorRepository {
  static final DonorRepository _instance = DonorRepository._internal();
  factory DonorRepository() => _instance;
  DonorRepository._internal();

  static DonorRepository get instance => _instance;

  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════════════
  // 📥 READ OPERATIONS
  // ═══════════════════════════════════════════════════════════════

  /// Get donor by user ID
  Future<DonorModel?> getDonorByUserId(String userId) async {
    try {
      final doc = await _fs.collection('users').doc(userId).get();

      if (!doc.exists) return null;

      final data = doc.data();
      if (data?['role'] != 'donor') return null;

      return DonorModel.fromDoc(doc);
    } catch (e) {
      print('❌ Error getting donor: $e');
      return null;
    }
  }

  /// Get all available donors
  Future<List<DonorModel>> getAllAvailableDonors() async {
    try {
      final snapshot = await _fs
          .collection('users')
          .where('role', isEqualTo: 'donor')
          .where('isAvailable', isEqualTo: true)
          .where('profileCompleted', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => DonorModel.fromDoc(doc))
          .toList();
    } catch (e) {
      print('❌ Error getting available donors: $e');
      return [];
    }
  }

  /// Get donors by blood type
  Future<List<DonorModel>> getDonorsByBloodType(String bloodType) async {
    try {
      final snapshot = await _fs
          .collection('users')
          .where('role', isEqualTo: 'donor')
          .where('bloodType', isEqualTo: bloodType)
          .where('isAvailable', isEqualTo: true)
          .where('profileCompleted', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => DonorModel.fromDoc(doc))
          .toList();
    } catch (e) {
      print('❌ Error getting donors by blood type: $e');
      return [];
    }
  }

  /// Get donors within radius
  Future<List<DonorModel>> getDonorsWithinRadius({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    try {
      // Get all available donors
      final allDonors = await getAllAvailableDonors();

      // Filter by distance
      final donorsWithinRadius = <DonorModel>[];

      for (final donor in allDonors) {
        if (!donor.hasValidLocation) continue;

        final distance = _calculateDistance(
          latitude,
          longitude,
          donor.latitude,
          donor.longitude,
        );

        if (distance <= radiusKm) {
          donorsWithinRadius.add(donor);
        }
      }

      // Sort by distance (closest first)
      donorsWithinRadius.sort((a, b) {
        final distA = _calculateDistance(latitude, longitude, a.latitude, a.longitude);
        final distB = _calculateDistance(latitude, longitude, b.latitude, b.longitude);
        return distA.compareTo(distB);
      });

      return donorsWithinRadius;

    } catch (e) {
      print('❌ Error getting donors within radius: $e');
      return [];
    }
  }

  /// Get compatible donors for blood type within radius
  Future<List<DonorModel>> getCompatibleDonors({
    required String recipientBloodType,
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    try {
      // Get compatible blood types
      final compatibleTypes = _getCompatibleBloodTypes(recipientBloodType);

      final compatibleDonors = <DonorModel>[];

      for (final bloodType in compatibleTypes) {
        final donors = await getDonorsByBloodType(bloodType);

        for (final donor in donors) {
          if (!donor.hasValidLocation) continue;

          final distance = _calculateDistance(
            latitude,
            longitude,
            donor.latitude,
            donor.longitude,
          );

          if (distance <= radiusKm) {
            compatibleDonors.add(donor);
          }
        }
      }

      // Remove duplicates
      final uniqueDonors = compatibleDonors.toSet().toList();

      // Sort by distance
      uniqueDonors.sort((a, b) {
        final distA = _calculateDistance(latitude, longitude, a.latitude, a.longitude);
        final distB = _calculateDistance(latitude, longitude, b.latitude, b.longitude);
        return distA.compareTo(distB);
      });

      return uniqueDonors;

    } catch (e) {
      print('❌ Error getting compatible donors: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 📤 WRITE OPERATIONS
  // ═══════════════════════════════════════════════════════════════

  /// Update donor availability
  Future<void> updateAvailability(String userId, bool isAvailable) async {
    try {
      await _fs.collection('users').doc(userId).update({
        'isAvailable': isAvailable,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Updated donor availability: $isAvailable');
    } catch (e) {
      print('❌ Error updating availability: $e');
      rethrow;
    }
  }

  /// Update donor location
  Future<void> updateLocation(
      String userId,
      double latitude,
      double longitude,
      ) async {
    try {
      await _fs.collection('users').doc(userId).update({
        'location': GeoPoint(latitude, longitude),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Updated donor location');
    } catch (e) {
      print('❌ Error updating location: $e');
      rethrow;
    }
  }

  /// Update last donation date
  Future<void> updateLastDonationDate(String userId, DateTime date) async {
    try {
      await _fs.collection('users').doc(userId).update({
        'lastDonationDate': Timestamp.fromDate(date),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Updated last donation date');
    } catch (e) {
      print('❌ Error updating last donation date: $e');
      rethrow;
    }
  }

  /// Save FCM token for donor
  Future<void> saveFCMToken(String userId, String token) async {
    try {
      await _fs.collection('users').doc(userId).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Saved FCM token for donor');
    } catch (e) {
      print('❌ Error saving FCM token: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 🔄 STREAMS
  // ═══════════════════════════════════════════════════════════════

  /// Stream donor data
  Stream<DonorModel?> streamDonor(String userId) {
    return _fs
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      if (doc.data()?['role'] != 'donor') return null;
      return DonorModel.fromDoc(doc);
    });
  }

  /// Stream all available donors
  Stream<List<DonorModel>> streamAvailableDonors() {
    return _fs
        .collection('users')
        .where('role', isEqualTo: 'donor')
        .where('isAvailable', isEqualTo: true)
        .where('profileCompleted', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => DonorModel.fromDoc(doc))
        .toList());
  }

  // ═══════════════════════════════════════════════════════════════
  // 🛠️ HELPER METHODS
  // ═══════════════════════════════════════════════════════════════

  /// Calculate distance using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // kilometers

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  /// Get compatible blood types for recipient
  List<String> _getCompatibleBloodTypes(String recipientBloodType) {
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

  // ═══════════════════════════════════════════════════════════════
  // 📊 STATISTICS
  // ═══════════════════════════════════════════════════════════════

  /// Get donor statistics
  Future<Map<String, dynamic>> getDonorStats(String userId) async {
    try {
      final donor = await getDonorByUserId(userId);
      if (donor == null) return {};

      // Get completed donations count
      final completedDonations = await _fs
          .collection('blood_requests')
          .where('acceptedBy', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .get();

      return {
        'totalDonations': completedDonations.docs.length,
        'isAvailable': donor.isAvailable,
        'bloodType': donor.bloodType,
        'lastDonation': donor.lastDonationDate,
        'canDonate': donor.canDonate,
        'isEligible': donor.isEligibleToDonate,
      };
    } catch (e) {
      print('❌ Error getting donor stats: $e');
      return {};
    }
  }
}

// Global instance
final donorRepository = DonorRepository.instance;