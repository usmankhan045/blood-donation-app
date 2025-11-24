// lib/models/blood_request_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class BloodRequest {
  final String id;
  final String requesterId;
  final String requesterName;
  final String bloodType;
  final int units;
  final String urgency; // "urgent" | "normal"
  final String city;
  final String address;
  final String? hospital;
  final String? notes;
  final String? phone;          // <-- NEW
  final GeoPoint? location;
  final String status; // active | accepted | completed | cancelled
  final String? acceptedBy;
  final DateTime? createdAt;
  final DateTime? neededBy;

  BloodRequest({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.bloodType,
    required this.units,
    required this.urgency,
    required this.city,
    required this.address,
    required this.location,
    required this.status,
    this.hospital,
    this.notes,
    this.phone,                  // NEW
    this.acceptedBy,
    this.createdAt,
    this.neededBy,
  });

  factory BloodRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};

    Timestamp? createdTs;
    final rawCreated = d['createdAt'];
    if (rawCreated is Timestamp) createdTs = rawCreated;

    Timestamp? neededTs;
    final rawNeeded = d['neededBy'];
    if (rawNeeded is Timestamp) neededTs = rawNeeded;

    int parseUnits(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      final s = v?.toString();
      final n = int.tryParse(s ?? '');
      return n ?? 1;
    }

    return BloodRequest(
      id: doc.id,
      requesterId: (d['requesterId'] ?? '') as String,
      requesterName: (d['requesterName'] ?? '') as String,
      bloodType: (d['bloodType'] ?? '') as String,
      units: parseUnits(d['units']),
      urgency: (d['urgency'] ?? 'normal') as String,
      city: (d['city'] ?? '') as String,
      address: (d['address'] ?? '') as String,
      hospital: (d['hospital'] as String?)?.trim(),
      notes: (d['notes'] as String?)?.trim(),
      phone: (d['phone'] as String?)?.trim(),            // NEW
      location: d['location'] is GeoPoint ? d['location'] as GeoPoint : null,
      status: (d['status'] ?? 'active') as String,
      acceptedBy: d['acceptedBy'] as String?,
      createdAt: createdTs?.toDate(),
      neededBy: neededTs?.toDate(),
    );
  }
}
