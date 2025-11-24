// lib/services/donor_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../repositories/blood_request_repository.dart';

class DonorService {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;
  final _requestRepo = BloodRequestRepository();

  Future<void> toggleAvailability(bool isAvailable) async {
    final uid = _auth.currentUser!.uid;
    await _fs.collection('users').doc(uid).set(
      {'isAvailable': isAvailable},
      SetOptions(merge: true),
    );
  }

  /// Accept a request as the current donor.
  Future<void> acceptRequest(String requestId) async {
    final uid = _auth.currentUser!.uid;
    await _requestRepo.acceptRequest(requestId: requestId, donorId: uid);
  }
}
