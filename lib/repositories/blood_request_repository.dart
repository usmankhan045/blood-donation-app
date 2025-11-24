// lib/repositories/blood_request_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/blood_request_model.dart';

/// Toggle this off when you switch to Cloud Functions + FCM in production.
const bool DEV_NOTIFIER = true;

/// Firestore collection keys
class _Coll {
  static const users = 'users';
  static const requests = 'blood_requests';
  static const userNotifications = 'user_notifications';
  static const inbox = 'inbox';
}

class BloodRequestRepository {
  BloodRequestRepository._internal();
  static final BloodRequestRepository instance = BloodRequestRepository._internal();

  /// Expose a default constructor so `BloodRequestRepository()` works anywhere.
  factory BloodRequestRepository() => instance;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Create a new blood request.
  /// While on free plan (no Cloud Functions), this also fans out dev notifications
  /// to eligible donors' inbox collections so they get in-app alerts.
  Future<String> createRequest({
    required String requesterId,
    required String requesterName,
    required String bloodType, // e.g. "A+"
    required int units,
    required String urgency, // "urgent" | "normal"
    required String city, // e.g. "Abbottabad"
    required String address,
    required GeoPoint location,
    String? hospital,                // optional
    String? notes,                   // optional
    String? phone,                   // optional
    dynamic neededBy,                // <-- accepts DateTime? OR Timestamp?
    Map<String, dynamic>? extra,
  }) async {
    final String cityNorm = city.trim();
    final String typeNorm = bloodType.trim().toUpperCase();

    // Normalize neededBy to Timestamp if provided
    Timestamp? neededTs;
    if (neededBy is Timestamp) {
      neededTs = neededBy;
    } else if (neededBy is DateTime) {
      neededTs = Timestamp.fromDate(neededBy);
    } else if (neededBy != null) {
      // anything else gets ignored; keeps things resilient
      // (you can throw if you prefer strict typing)
    }

    final reqRef = _firestore.collection(_Coll.requests).doc();
    final payload = <String, dynamic>{
      'requesterId': requesterId,
      'requesterName': requesterName,
      'bloodType': typeNorm,
      'units': units,
      'urgency': urgency,
      'city': cityNorm,
      'address': address,
      'location': location,
      if (hospital != null && hospital.trim().isNotEmpty) 'hospital': hospital.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      'status': 'active', // active | accepted | completed | cancelled
      'acceptedBy': null,
      'createdAt': FieldValue.serverTimestamp(),
      'neededBy': neededTs, // <-- normalized here
      ...?extra,
    };

    await reqRef.set(payload);
    final requestId = reqRef.id;

    if (DEV_NOTIFIER) {
      _fanOutToEligibleDonorsDev(
        requestId: requestId,
        requesterName: requesterName,
        bloodType: typeNorm,
        city: cityNorm,
        address: address,
      ).ignore();
    }

    return requestId;
  }

  /// Stream active requests matching a donor's city + bloodType, newest first.
  Stream<List<BloodRequest>> streamActiveForDonor({
    required String donorCity,
    required String donorBloodType,
  }) {
    final city = donorCity.trim();
    final type = donorBloodType.trim().toUpperCase();

    final query = _firestore
        .collection(_Coll.requests)
        .where('city', isEqualTo: city)
        .where('status', isEqualTo: 'active')
        .where('bloodType', isEqualTo: type)
        .orderBy('createdAt', descending: true);

    return query.snapshots().map((snap) {
      return snap.docs
          .map((d) => BloodRequest.fromDoc(d as DocumentSnapshot<Map<String, dynamic>>))
          .toList(growable: false);
    });
  }

  /// Mark a request as accepted by a donor.
  /// If [donorId] is not provided, current user is used.
  Future<void> acceptRequest({
    required String requestId,
    String? donorId,
  }) async {
    final uid = donorId ?? _auth.currentUser!.uid;
    await _firestore.runTransaction((tx) async {
      final ref = _firestore.collection(_Coll.requests).doc(requestId);
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw Exception('Request not found');
      }
      final status = (snap.data()?['status'] as String?) ?? 'active';
      if (status != 'active') {
        throw Exception('Request is not active');
      }
      tx.update(ref, {
        'status': 'accepted',
        'acceptedBy': uid,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// DEV-ONLY: simulate push by writing an inbox doc for each eligible donor.
  /// donors query: role=donor, city==city, bloodType==type, isAvailable==true
  Future<void> _fanOutToEligibleDonorsDev({
    required String requestId,
    required String requesterName,
    required String bloodType,
    required String city,
    required String address,
  }) async {
    try {
      final donorsSnap = await _firestore
          .collection(_Coll.users)
          .where('role', isEqualTo: 'donor')
          .where('city', isEqualTo: city)
          .where('bloodType', isEqualTo: bloodType)
          .where('isAvailable', isEqualTo: true)
          .get();

      if (donorsSnap.docs.isEmpty) return;

      // Batch in chunks to stay under limits.
      const maxPerBatch = 400;
      List<WriteBatch> batches = [];
      WriteBatch current = _firestore.batch();
      int ops = 0;

      for (final d in donorsSnap.docs) {
        final notifRef = _firestore
            .collection(_Coll.userNotifications)
            .doc(d.id)
            .collection(_Coll.inbox)
            .doc();

        current.set(notifRef, {
          'type': 'blood_request',
          'requestId': requestId,
          'title': 'Blood request: $bloodType needed',
          'body': '$requesterName • $address',
          'city': city,
          'bloodType': bloodType,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        ops++;

        if (ops >= maxPerBatch) {
          batches.add(current);
          current = _firestore.batch();
          ops = 0;
        }
      }

      if (ops > 0) batches.add(current);
      for (final b in batches) {
        await b.commit();
      }
    } catch (_) {
      // dev notifier failing shouldn't break the flow
    }
  }
}

extension _FutureIgnore on Future<void> {
  void ignore() {}
}
