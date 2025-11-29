import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role; // 'admin', 'super_admin', 'donor', 'hospital', 'blood_bank', 'recipient'
  final bool isSuperAdmin;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final bool isActive;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.isSuperAdmin = false,
    required this.createdAt,
    this.lastLogin,
    this.isActive = true,
  });

  // Add toJson and fromJson methods
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'isSuperAdmin': isSuperAdmin,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
      'isActive': isActive,
    };
  }

  static UserModel fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      isSuperAdmin: json['isSuperAdmin'] ?? false,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      lastLogin: json['lastLogin'] != null ? (json['lastLogin'] as Timestamp).toDate() : null,
      isActive: json['isActive'] ?? true,
    );
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? role,
    bool? isSuperAdmin,
    DateTime? createdAt,
    DateTime? lastLogin,
    bool? isActive,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      isActive: isActive ?? this.isActive,
    );
  }
}