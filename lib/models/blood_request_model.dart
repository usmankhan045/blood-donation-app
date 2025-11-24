import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BloodRequest {
  final String id;
  final String requesterId;
  final String requesterName;
  final String bloodType;
  final int units;
  final String urgency; // "low", "normal", "high", "emergency"
  final String city;
  final String address;
  final String? hospital;
  final String? notes;
  final String? phone;
  final GeoPoint? location;
  final String status; // active | accepted | completed | cancelled
  final String? acceptedBy;
  final DateTime? createdAt;
  final DateTime? neededBy;
  final int searchRadius; // in kilometers
  final List<String> notifiedDonors; // Track which donors were notified
  final String? donorToken; // Add donorToken field
  final String? recipientToken; // Add recipientToken field

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
    this.phone,
    this.acceptedBy,
    this.createdAt,
    this.neededBy,
    this.searchRadius = 10, // Default 10km radius
    this.notifiedDonors = const [],
    this.donorToken, // Initialize donorToken
    this.recipientToken, // Initialize recipientToken
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
      phone: (d['phone'] as String?)?.trim(),
      location: d['location'] is GeoPoint ? d['location'] as GeoPoint : null,
      status: (d['status'] ?? 'active') as String,
      acceptedBy: d['acceptedBy'] as String?,
      createdAt: createdTs?.toDate(),
      neededBy: neededTs?.toDate(),
      searchRadius: (d['searchRadius'] as int?) ?? 10,
      notifiedDonors: List<String>.from(d['notifiedDonors'] ?? []),
      donorToken: d['donorToken'] as String?, // Parse donorToken
      recipientToken: d['recipientToken'] as String?, // Parse recipientToken
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requesterId': requesterId,
      'requesterName': requesterName,
      'bloodType': bloodType,
      'units': units,
      'urgency': urgency,
      'city': city,
      'address': address,
      'hospital': hospital,
      'notes': notes,
      'phone': phone,
      'location': location,
      'status': status,
      'acceptedBy': acceptedBy,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'neededBy': neededBy != null ? Timestamp.fromDate(neededBy!) : null,
      'searchRadius': searchRadius,
      'notifiedDonors': notifiedDonors,
      'donorToken': donorToken, // Include donorToken in toMap
      'recipientToken': recipientToken, // Include recipientToken in toMap
    };
  }

  // Helper method to check if request is urgent
  bool get isUrgent => urgency == 'high' || urgency == 'emergency';

  // Helper method to get urgency color
  Color get urgencyColor {
    switch (urgency) {
      case 'emergency': return Colors.red;
      case 'high': return Colors.orange;
      case 'normal': return Colors.blue;
      case 'low': return Colors.green;
      default: return Colors.grey;
    }
  }
}