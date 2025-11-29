import 'package:cloud_firestore/cloud_firestore.dart';

class BloodBankModel {
  final String uid;
  final String bloodBankName;
  final String registrationNo;
  final String contactPerson;
  final String designation;
  final String phoneNumber;
  final String email;
  final String address;
  final String city;
  final String operatingHours;
  final String? bloodBankType;
  final List<String> availableBloodTypes;
  final String emergencyPhone;
  final bool available24Hours;
  final bool acceptsDonations;
  final Map<String, dynamic> inventory;
  final bool profileCompleted;
  final bool isVerified;
  final int totalRequests;
  final int activeRequests;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final GeoPoint? location;

  BloodBankModel({
    required this.uid,
    required this.bloodBankName,
    required this.registrationNo,
    required this.contactPerson,
    required this.designation,
    required this.phoneNumber,
    required this.email,
    required this.address,
    required this.city,
    required this.operatingHours,
    this.bloodBankType,
    required this.availableBloodTypes,
    required this.emergencyPhone,
    this.available24Hours = false,
    this.acceptsDonations = true,
    required this.inventory,
    this.profileCompleted = false,
    this.isVerified = false,
    this.totalRequests = 0,
    this.activeRequests = 0,
    this.createdAt,
    this.updatedAt,
    this.location,
  });

  // Convert Firestore document to BloodBankModel
  factory BloodBankModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return BloodBankModel(
      uid: doc.id,
      bloodBankName: data['bloodBankName'] ?? '',
      registrationNo: data['registrationNo'] ?? '',
      contactPerson: data['contactPerson'] ?? '',
      designation: data['designation'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      email: data['email'] ?? '',
      address: data['address'] ?? '',
      city: data['city'] ?? '',
      operatingHours: data['operatingHours'] ?? '',
      bloodBankType: data['bloodBankType'],
      availableBloodTypes: List<String>.from(data['availableBloodTypes'] ?? []),
      emergencyPhone: data['emergencyPhone'] ?? '',
      available24Hours: data['available24Hours'] ?? false,
      acceptsDonations: data['acceptsDonations'] ?? true,
      inventory: Map<String, dynamic>.from(data['inventory'] ?? {}),
      profileCompleted: data['profileCompleted'] ?? false,
      isVerified: data['isVerified'] ?? false,
      totalRequests: data['totalRequests'] ?? 0,
      activeRequests: data['activeRequests'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      location: data['location'] as GeoPoint?,
    );
  }

  // Convert BloodBankModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'bloodBankName': bloodBankName,
      'registrationNo': registrationNo,
      'contactPerson': contactPerson,
      'designation': designation,
      'phoneNumber': phoneNumber,
      'email': email,
      'address': address,
      'city': city,
      'operatingHours': operatingHours,
      'bloodBankType': bloodBankType,
      'availableBloodTypes': availableBloodTypes,
      'emergencyPhone': emergencyPhone,
      'available24Hours': available24Hours,
      'acceptsDonations': acceptsDonations,
      'inventory': inventory,
      'profileCompleted': profileCompleted,
      'userType': 'blood_bank',
      'isVerified': isVerified,
      'totalRequests': totalRequests,
      'activeRequests': activeRequests,
      'updatedAt': FieldValue.serverTimestamp(),
      if (location != null) 'location': location,
    };
  }

  // Get total units in inventory
  int get totalUnits {
    int total = 0;
    inventory.forEach((bloodType, data) {
      if (data is Map && data.containsKey('units')) {
        total += (data['units'] as int);
      }
    });
    return total;
  }

  // Get blood types with low stock (less than 5 units)
  List<String> get lowStockBloodTypes {
    List<String> lowStock = [];
    inventory.forEach((bloodType, data) {
      if (data is Map && data.containsKey('units')) {
        int units = data['units'] as int;
        if (units < 5 && units > 0) {
          lowStock.add(bloodType);
        }
      }
    });
    return lowStock;
  }

  // Get blood types that are out of stock
  List<String> get outOfStockBloodTypes {
    List<String> outOfStock = [];
    inventory.forEach((bloodType, data) {
      if (data is Map && data.containsKey('units')) {
        int units = data['units'] as int;
        if (units == 0) {
          outOfStock.add(bloodType);
        }
      }
    });
    return outOfStock;
  }

  // Get available blood types with stock
  Map<String, int> get availableStock {
    Map<String, int> available = {};
    inventory.forEach((bloodType, data) {
      if (data is Map && data.containsKey('units')) {
        int units = data['units'] as int;
        if (units > 0) {
          available[bloodType] = units;
        }
      }
    });
    return available;
  }

  // Copy with method for updating model
  BloodBankModel copyWith({
    String? uid,
    String? bloodBankName,
    String? registrationNo,
    String? contactPerson,
    String? designation,
    String? phoneNumber,
    String? email,
    String? address,
    String? city,
    String? operatingHours,
    String? bloodBankType,
    List<String>? availableBloodTypes,
    String? emergencyPhone,
    bool? available24Hours,
    bool? acceptsDonations,
    Map<String, dynamic>? inventory,
    bool? profileCompleted,
    bool? isVerified,
    int? totalRequests,
    int? activeRequests,
    DateTime? createdAt,
    DateTime? updatedAt,
    GeoPoint? location,
  }) {
    return BloodBankModel(
      uid: uid ?? this.uid,
      bloodBankName: bloodBankName ?? this.bloodBankName,
      registrationNo: registrationNo ?? this.registrationNo,
      contactPerson: contactPerson ?? this.contactPerson,
      designation: designation ?? this.designation,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      operatingHours: operatingHours ?? this.operatingHours,
      bloodBankType: bloodBankType ?? this.bloodBankType,
      availableBloodTypes: availableBloodTypes ?? this.availableBloodTypes,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      available24Hours: available24Hours ?? this.available24Hours,
      acceptsDonations: acceptsDonations ?? this.acceptsDonations,
      inventory: inventory ?? this.inventory,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      isVerified: isVerified ?? this.isVerified,
      totalRequests: totalRequests ?? this.totalRequests,
      activeRequests: activeRequests ?? this.activeRequests,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      location: location ?? this.location,
    );
  }
}