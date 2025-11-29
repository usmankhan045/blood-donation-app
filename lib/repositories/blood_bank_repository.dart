import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:blood_donation_app/models/blood_bank_model.dart';

class BloodBankRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get blood bank by UID
  Future<BloodBankModel?> getBloodBankByUid(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        return BloodBankModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting blood bank: $e');
      rethrow;
    }
  }

  // Create or update blood bank profile
  Future<void> saveBloodBankProfile(String uid, BloodBankModel bloodBank) async {
    try {
      await _firestore.collection('users').doc(uid).set(
        bloodBank.toMap(),
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error saving blood bank profile: $e');
      rethrow;
    }
  }

  // Update inventory for a specific blood type
  Future<void> updateInventory(String uid, String bloodType, int units) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'inventory.$bloodType.units': units,
        'inventory.$bloodType.lastUpdated': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating inventory: $e');
      rethrow;
    }
  }

  // Add new blood type to inventory
  Future<void> addBloodTypeToInventory(String uid, String bloodType, int units) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'availableBloodTypes': FieldValue.arrayUnion([bloodType]),
        'inventory.$bloodType': {
          'units': units,
          'lastUpdated': FieldValue.serverTimestamp(),
          'status': 'Available'
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding blood type to inventory: $e');
      rethrow;
    }
  }

  // Remove blood type from inventory
  Future<void> removeBloodTypeFromInventory(String uid, String bloodType) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'availableBloodTypes': FieldValue.arrayRemove([bloodType]),
        'inventory.$bloodType': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error removing blood type from inventory: $e');
      rethrow;
    }
  }

  // Get all blood banks
  Future<List<BloodBankModel>> getAllBloodBanks() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'blood_bank')
          .where('profileCompleted', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => BloodBankModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting all blood banks: $e');
      rethrow;
    }
  }

  // Get blood banks by city
  Future<List<BloodBankModel>> getBloodBanksByCity(String city) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'blood_bank')
          .where('city', isEqualTo: city)
          .where('profileCompleted', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => BloodBankModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting blood banks by city: $e');
      rethrow;
    }
  }

  // Search blood banks by blood type availability
  Future<List<BloodBankModel>> searchBloodBanksByBloodType(String bloodType) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'blood_bank')
          .where('availableBloodTypes', arrayContains: bloodType)
          .where('profileCompleted', isEqualTo: true)
          .get();

      // Filter by actual stock availability
      List<BloodBankModel> bloodBanks = [];
      for (var doc in snapshot.docs) {
        BloodBankModel bloodBank = BloodBankModel.fromFirestore(doc);
        if (bloodBank.inventory.containsKey(bloodType)) {
          var bloodData = bloodBank.inventory[bloodType];
          if (bloodData is Map && bloodData['units'] > 0) {
            bloodBanks.add(bloodBank);
          }
        }
      }

      return bloodBanks;
    } catch (e) {
      print('Error searching blood banks by blood type: $e');
      rethrow;
    }
  }

  // Update blood bank verification status (admin only)
  Future<void> updateVerificationStatus(String uid, bool isVerified) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isVerified': isVerified,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating verification status: $e');
      rethrow;
    }
  }

  // Get blood bank statistics
  Future<Map<String, dynamic>> getBloodBankStats(String uid) async {
    try {
      BloodBankModel? bloodBank = await getBloodBankByUid(uid);

      if (bloodBank == null) {
        return {
          'totalUnits': 0,
          'bloodTypesAvailable': 0,
          'lowStockCount': 0,
          'outOfStockCount': 0,
        };
      }

      return {
        'totalUnits': bloodBank.totalUnits,
        'bloodTypesAvailable': bloodBank.availableStock.length,
        'lowStockCount': bloodBank.lowStockBloodTypes.length,
        'outOfStockCount': bloodBank.outOfStockBloodTypes.length,
        'totalRequests': bloodBank.totalRequests,
        'activeRequests': bloodBank.activeRequests,
      };
    } catch (e) {
      print('Error getting blood bank stats: $e');
      rethrow;
    }
  }

  // Stream blood bank data for real-time updates
  Stream<BloodBankModel?> streamBloodBank(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return BloodBankModel.fromFirestore(doc);
      }
      return null;
    });
  }

  // Batch update inventory (for multiple blood types at once)
  Future<void> batchUpdateInventory(String uid, Map<String, int> updates) async {
    try {
      Map<String, dynamic> updateData = {};

      updates.forEach((bloodType, units) {
        updateData['inventory.$bloodType.units'] = units;
        updateData['inventory.$bloodType.lastUpdated'] = FieldValue.serverTimestamp();
      });

      updateData['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection('users').doc(uid).update(updateData);
    } catch (e) {
      print('Error batch updating inventory: $e');
      rethrow;
    }
  }

  // Check if blood bank profile is complete
  Future<bool> isProfileComplete(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        return doc.get('profileCompleted') ?? false;
      }
      return false;
    } catch (e) {
      print('Error checking profile completion: $e');
      return false;
    }
  }
}