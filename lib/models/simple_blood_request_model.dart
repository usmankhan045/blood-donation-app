import 'package:cloud_firestore/cloud_firestore.dart';

class SimpleBloodRequest {
  final String id;
  final String bloodType;
  final int units;
  final String status;
  final String city;
  final String address;
  final String? hospital;
  final String? phone;
  final String? notes;
  final String? acceptedBy;
  final DateTime? createdAt;
  final DateTime? neededBy;
  final String urgency;
  final int searchRadius;

  SimpleBloodRequest({
    required this.id,
    required this.bloodType,
    required this.units,
    required this.status,
    required this.city,
    required this.address,
    this.hospital,
    this.phone,
    this.notes,
    this.acceptedBy,
    this.createdAt,
    this.neededBy,
    required this.urgency,
    required this.searchRadius,
  });

  // Factory method to create from Firestore document
  factory SimpleBloodRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    return SimpleBloodRequest(
      id: doc.id,
      bloodType: data['bloodType'] ?? 'Unknown',
      units: (data['units'] as num?)?.toInt() ?? 1,
      status: data['status'] ?? 'active',
      city: data['city'] ?? '',
      address: data['address'] ?? '',
      hospital: data['hospital'],
      phone: data['phone'],
      notes: data['notes'],
      acceptedBy: data['acceptedBy'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      neededBy: (data['neededBy'] as Timestamp?)?.toDate(),
      urgency: data['urgency'] ?? 'normal',
      searchRadius: (data['searchRadius'] as num?)?.toInt() ?? 10,
    );
  }
}