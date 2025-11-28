import 'package:cloud_firestore/cloud_firestore.dart';

class DonorModel {
  final String id;
  final String userId;
  final String fullName;
  final String email;
  final String phone;
  final String bloodType;
  final String gender;
  final DateTime dateOfBirth;
  final double latitude;
  final double longitude;
  final String address;
  final bool isAvailable;
  final DateTime lastDonationDate;
  final bool canDonate;
  final DateTime createdAt;
  final DateTime updatedAt;

  DonorModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.bloodType,
    required this.gender,
    required this.dateOfBirth,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.isAvailable,
    required this.lastDonationDate,
    required this.canDonate,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'bloodType': bloodType,
      'gender': gender,
      'dateOfBirth': dateOfBirth.millisecondsSinceEpoch,
      'location': GeoPoint(latitude, longitude),
      'address': address,
      'isAvailable': isAvailable,
      'lastDonationDate': lastDonationDate.millisecondsSinceEpoch,
      'canDonate': canDonate,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  // Create from DocumentSnapshot - FIXED TIMESTAMP HANDLING
  factory DonorModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // ✅ UPDATED: Handle both GeoPoint and separate lat/lng fields for backward compatibility
    double latitude = 0.0;
    double longitude = 0.0;

    if (data['location'] != null && data['location'] is GeoPoint) {
      GeoPoint location = data['location'] as GeoPoint;
      latitude = location.latitude;
      longitude = location.longitude;
    } else {
      latitude = (data['latitude'] ?? 0.0).toDouble();
      longitude = (data['longitude'] ?? 0.0).toDouble();
    }

    // ✅ UPDATED: Handle Timestamp fields properly
    DateTime parseDate(dynamic dateField) {
      if (dateField == null) return DateTime.now();
      if (dateField is Timestamp) {
        return dateField.toDate();
      } else if (dateField is String) {
        return DateTime.parse(dateField);
      } else if (dateField is int) {
        return DateTime.fromMillisecondsSinceEpoch(dateField);
      } else {
        return DateTime.now();
      }
    }

    return DonorModel(
      id: doc.id,
      userId: data['userId'] ?? doc.id,
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? data['phoneNumber'] ?? '',
      bloodType: data['bloodType'] ?? data['bloodGroup'] ?? '',
      gender: data['gender'] ?? '',
      dateOfBirth: parseDate(data['dob'] ?? data['dateOfBirth']),
      latitude: latitude,
      longitude: longitude,
      address: data['address'] ?? '',
      isAvailable: data['isAvailable'] ?? true,
      lastDonationDate: parseDate(data['lastDonationDate']),
      canDonate: data['canDonate'] ?? true,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  // Create from JSON
  factory DonorModel.fromJson(Map<String, dynamic> json) {
    // Handle both GeoPoint and separate lat/lng fields
    double latitude = 0.0;
    double longitude = 0.0;

    if (json['location'] != null && json['location'] is Map) {
      Map<String, dynamic> location = json['location'];
      latitude = (location['latitude'] ?? 0.0).toDouble();
      longitude = (location['longitude'] ?? 0.0).toDouble();
    } else if (json['location'] != null && json['location'] is GeoPoint) {
      GeoPoint location = json['location'] as GeoPoint;
      latitude = location.latitude;
      longitude = location.longitude;
    } else {
      latitude = (json['latitude'] ?? 0.0).toDouble();
      longitude = (json['longitude'] ?? 0.0).toDouble();
    }

    DateTime parseJsonDate(dynamic dateField) {
      if (dateField == null) return DateTime.now();
      if (dateField is int) {
        return DateTime.fromMillisecondsSinceEpoch(dateField);
      } else if (dateField is String) {
        return DateTime.parse(dateField);
      } else {
        return DateTime.now();
      }
    }

    return DonorModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? json['phoneNumber'] ?? '',
      bloodType: json['bloodType'] ?? json['bloodGroup'] ?? '',
      gender: json['gender'] ?? '',
      dateOfBirth: parseJsonDate(json['dob'] ?? json['dateOfBirth']),
      latitude: latitude,
      longitude: longitude,
      address: json['address'] ?? '',
      isAvailable: json['isAvailable'] ?? true,
      lastDonationDate: parseJsonDate(json['lastDonationDate']),
      canDonate: json['canDonate'] ?? true,
      createdAt: parseJsonDate(json['createdAt']),
      updatedAt: parseJsonDate(json['updatedAt']),
    );
  }

  // Copy with method
  DonorModel copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? email,
    String? phone,
    String? bloodType,
    String? gender,
    DateTime? dateOfBirth,
    double? latitude,
    double? longitude,
    String? address,
    bool? isAvailable,
    DateTime? lastDonationDate,
    bool? canDonate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DonorModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      bloodType: bloodType ?? this.bloodType,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      isAvailable: isAvailable ?? this.isAvailable,
      lastDonationDate: lastDonationDate ?? this.lastDonationDate,
      canDonate: canDonate ?? this.canDonate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper method to get GeoPoint
  GeoPoint get locationGeoPoint => GeoPoint(latitude, longitude);

  // Check if donor has valid location
  bool get hasValidLocation => latitude != 0.0 && longitude != 0.0;

  // Calculate age from date of birth
  int get age {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  // Check if donor is eligible to donate based on age and last donation
  bool get isEligibleToDonate {
    final now = DateTime.now();

    // Check age (typically 18-65 years)
    if (age < 18 || age > 65) return false;

    // Check if enough time has passed since last donation (typically 3 months)
    if (lastDonationDate != DateTime.fromMillisecondsSinceEpoch(0)) {
      final monthsSinceLastDonation = (now.difference(lastDonationDate).inDays / 30).floor();
      if (monthsSinceLastDonation < 3) return false;
    }

    return canDonate && isAvailable;
  }
}