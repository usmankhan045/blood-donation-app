// lib/services/donor_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/blood_request_model.dart';

class DonorService {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  Future<void> toggleAvailability(bool isAvailable) async {
    final uid = _auth.currentUser!.uid;
    await _fs.collection('users').doc(uid).set(
      {'isAvailable': isAvailable},
      SetOptions(merge: true),
    );
  }

  /// Get donor's current availability status
  Future<bool> getDonorAvailability() async {
    final uid = _auth.currentUser!.uid;
    final doc = await _fs.collection('users').doc(uid).get();
    return doc.data()?['isAvailable'] ?? false;
  }

  /// Accept a blood request as the current donor
  Future<void> acceptRequest(String requestId, String donorName) async {
    try {
      final uid = _auth.currentUser!.uid;

      // Update request status to accepted
      await _fs.collection('blood_requests').doc(requestId).update({
        'status': 'accepted',
        'acceptedBy': uid,
        'acceptedByName': donorName,
        'acceptedByType': 'donor',
        'acceptedAt': FieldValue.serverTimestamp(),
        // Clear potential donors array
        'potentialDonors': [],
      });

      print('✅ Request $requestId accepted by donor $uid');
    } catch (e) {
      print('❌ Error accepting request: $e');
      rethrow;
    }
  }

  /// Decline a blood request
  Future<void> declineRequest(String requestId) async {
    try {
      // Remove donor from potentialDonors to avoid showing them this request again
      await _fs.collection('blood_requests').doc(requestId).update({
        'potentialDonors': FieldValue.arrayRemove([_auth.currentUser!.uid])
      });

      print('✅ Donor declined request: $requestId');
    } catch (e) {
      print('❌ Error declining request: $e');
    }
  }

  /// Complete a blood request (donor marks it as completed)
  Future<void> completeRequest(String requestId) async {
    try {
      final uid = _auth.currentUser!.uid;
      final donorProfile = await getDonorProfile();
      final donorName = donorProfile?['fullName'] ?? 'A Donor';

      // Update request status to completed
      await _fs.collection('blood_requests').doc(requestId).update({
        'status': 'completed',
        'completedBy': uid,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Update donor's donation history
      await _updateDonorDonationHistory(uid);

      print('✅ Request $requestId marked as completed by donor $uid');
    } catch (e) {
      print('❌ Error completing request: $e');
      rethrow;
    }
  }

  /// Get available blood requests for the current donor
  Stream<List<BloodRequest>> getAvailableRequests() {
    final uid = _auth.currentUser!.uid;

    return _fs
        .collection('blood_requests')
        .where('status', isEqualTo: 'pending')
        .where('potentialDonors', arrayContains: uid)
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

  /// Get donor's accepted requests
  Stream<List<BloodRequest>> getAcceptedRequests() {
    final uid = _auth.currentUser!.uid;

    return _fs
        .collection('blood_requests')
        .where('acceptedBy', isEqualTo: uid)
        .where('acceptedByType', isEqualTo: 'donor')
        .where('status', whereIn: ['accepted', 'completed'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      return BloodRequest.fromMap(data, doc.id);
    })
        .toList());
  }

  /// Get donor's donation history
  Stream<List<BloodRequest>> getDonationHistory() {
    final uid = _auth.currentUser!.uid;

    return _fs
        .collection('blood_requests')
        .where('acceptedBy', isEqualTo: uid)
        .where('acceptedByType', isEqualTo: 'donor')
        .where('status', isEqualTo: 'completed')
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      return BloodRequest.fromMap(data, doc.id);
    })
        .toList());
  }

  /// Update donor profile with donation information
  Future<void> _updateDonorDonationHistory(String donorId) async {
    try {
      // Get current donation count
      final donorDoc = await _fs.collection('users').doc(donorId).get();
      final currentData = donorDoc.data() ?? {};
      final currentDonations = (currentData['totalDonations'] as int?) ?? 0;

      // Update donor profile
      await _fs.collection('users').doc(donorId).update({
        'totalDonations': currentDonations + 1,
        'lastDonationDate': FieldValue.serverTimestamp(),
        'isAvailable': false, // Make donor unavailable after donation
      });

      print('✅ Updated donation history for donor $donorId');
    } catch (e) {
      print('❌ Error updating donor history: $e');
    }
  }

  /// Get donor profile information
  Future<Map<String, dynamic>?> getDonorProfile() async {
    try {
      final uid = _auth.currentUser!.uid;
      final doc = await _fs.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      print('❌ Error getting donor profile: $e');
      return null;
    }
  }

  /// Update donor's last known location
  Future<void> updateDonorLocation(double lat, double lng, String address) async {
    try {
      final uid = _auth.currentUser!.uid;
      await _fs.collection('users').doc(uid).update({
        'location': GeoPoint(lat, lng),
        'address': address,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Donor location updated: $lat, $lng');
    } catch (e) {
      print('❌ Error updating donor location: $e');
    }
  }

  /// Get donor statistics
  Future<Map<String, dynamic>> getDonorStats() async {
    try {
      final uid = _auth.currentUser!.uid;

      // Get total donations
      final completedDonations = await _fs
          .collection('blood_requests')
          .where('acceptedBy', isEqualTo: uid)
          .where('acceptedByType', isEqualTo: 'donor')
          .where('status', isEqualTo: 'completed')
          .get();

      // Get pending accepted requests
      final pendingRequests = await _fs
          .collection('blood_requests')
          .where('acceptedBy', isEqualTo: uid)
          .where('acceptedByType', isEqualTo: 'donor')
          .where('status', isEqualTo: 'accepted')
          .get();

      return {
        'totalDonations': completedDonations.docs.length,
        'pendingRequests': pendingRequests.docs.length,
        'livesSaved': completedDonations.docs.length, // Each donation saves a life
      };
    } catch (e) {
      print('❌ Error getting donor stats: $e');
      return {
        'totalDonations': 0,
        'pendingRequests': 0,
        'livesSaved': 0,
      };
    }
  }
}