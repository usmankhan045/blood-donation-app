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
  final String status; // active | accepted | completed | cancelled | expired
  final String? acceptedBy;
  final String? acceptedByName;
  final String? acceptedByType; // 'donor' or 'blood_bank'
  final String? acceptedBloodBankName; // Name of the blood bank if accepted by one
  final DateTime? createdAt;
  final DateTime? neededBy;
  final int searchRadius; // in kilometers
  final List<String> notifiedDonors; // Track which donors were notified
  final List<String>? notifiedBloodBanks; // Track which blood banks were notified
  final String? donorToken;
  final String? recipientToken;
  final double latitude;
  final double longitude;

  // ✅ ADDED: Potential donors array for donor matching
  final List<String> potentialDonors;

  // UPDATED: 1 HOUR expiration and timeline fields
  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime? expiredAt;

  // NEW: Constant for 1-hour expiration
  static const Duration expirationDuration = Duration(hours: 1);

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
    this.acceptedByName,
    this.acceptedByType,
    this.acceptedBloodBankName,
    DateTime? createdAt,
    this.neededBy,
    this.searchRadius = 10,
    this.notifiedDonors = const [],
    this.notifiedBloodBanks,
    this.donorToken,
    this.recipientToken,
    required this.latitude,
    required this.longitude,
    // ✅ ADDED: Potential donors array
    this.potentialDonors = const [],
    // UPDATED: Initialize expiration with 1-hour default
    DateTime? expiresAt,
    this.acceptedAt,
    this.completedAt,
    this.cancelledAt,
    this.expiredAt,
  }) : createdAt = createdAt ?? DateTime.now(),
        expiresAt = expiresAt ?? (createdAt ?? DateTime.now()).add(expirationDuration);

  // ✅ ADDED: Factory constructor from Map (for donor matching service)
  factory BloodRequest.fromMap(Map<String, dynamic> data, String id) {
    // Helper function to parse timestamp
    DateTime? _parseTimestamp(dynamic timestamp) {
      if (timestamp is Timestamp) return timestamp.toDate();
      if (timestamp is int) return DateTime.fromMillisecondsSinceEpoch(timestamp);
      return null;
    }

    int parseUnits(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      final s = v?.toString();
      final n = int.tryParse(s ?? '');
      return n ?? 1;
    }

    // Extract latitude and longitude
    double latitude = 0.0;
    double longitude = 0.0;

    if (data['location'] is GeoPoint) {
      final geoPoint = data['location'] as GeoPoint;
      latitude = geoPoint.latitude;
      longitude = geoPoint.longitude;
    } else {
      latitude = (data['latitude'] ?? 0.0).toDouble();
      longitude = (data['longitude'] ?? 0.0).toDouble();
    }

    // Calculate expiresAt if not present (backward compatibility)
    DateTime? createdAt = _parseTimestamp(data['createdAt']);
    DateTime? expiresAt = _parseTimestamp(data['expiresAt']);

    // If expiresAt is not set but createdAt is, set default 1-hour expiration
    if (expiresAt == null && createdAt != null) {
      expiresAt = createdAt.add(expirationDuration);
    }

    return BloodRequest(
      id: id,
      requesterId: (data['requesterId'] ?? '') as String,
      requesterName: (data['requesterName'] ?? '') as String,
      bloodType: (data['bloodType'] ?? '') as String,
      units: parseUnits(data['units']),
      urgency: (data['urgency'] ?? 'normal') as String,
      city: (data['city'] ?? '') as String,
      address: (data['address'] ?? '') as String,
      hospital: (data['hospital'] as String?)?.trim(),
      notes: (data['notes'] as String?)?.trim(),
      phone: (data['phone'] as String?)?.trim(),
      location: data['location'] is GeoPoint ? data['location'] as GeoPoint : null,
      status: (data['status'] ?? 'active') as String,
      acceptedBy: data['acceptedBy'] as String?,
      acceptedByName: data['acceptedByName'] as String?,
      acceptedByType: data['acceptedByType'] as String?,
      acceptedBloodBankName: data['acceptedBloodBankName'] as String?,
      createdAt: createdAt,
      neededBy: _parseTimestamp(data['neededBy']),
      searchRadius: (data['searchRadius'] as int?) ?? 10,
      notifiedDonors: List<String>.from(data['notifiedDonors'] ?? []),
      notifiedBloodBanks: List<String>.from(data['notifiedBloodBanks'] ?? []),
      donorToken: data['donorToken'] as String?,
      recipientToken: data['recipientToken'] as String?,
      latitude: latitude,
      longitude: longitude,
      // ✅ ADDED: Potential donors array
      potentialDonors: List<String>.from(data['potentialDonors'] ?? []),
      // UPDATED: Parse timeline fields with 1-hour logic
      expiresAt: expiresAt,
      acceptedAt: _parseTimestamp(data['acceptedAt']),
      completedAt: _parseTimestamp(data['completedAt']),
      cancelledAt: _parseTimestamp(data['cancelledAt']),
      expiredAt: _parseTimestamp(data['expiredAt']),
    );
  }

  factory BloodRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return BloodRequest.fromMap(doc.data() ?? const <String, dynamic>{}, doc.id);
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
      'acceptedByName': acceptedByName,
      'acceptedByType': acceptedByType,
      'acceptedBloodBankName': acceptedBloodBankName,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'neededBy': neededBy != null ? Timestamp.fromDate(neededBy!) : null,
      'searchRadius': searchRadius,
      'notifiedDonors': notifiedDonors,
      'notifiedBloodBanks': notifiedBloodBanks ?? [],
      'donorToken': donorToken,
      'recipientToken': recipientToken,
      'latitude': latitude,
      'longitude': longitude,
      // ✅ ADDED: Potential donors array
      'potentialDonors': potentialDonors,
      // UPDATED: Include timeline fields with 1-hour expiration
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : Timestamp.fromDate(createdAt!.add(expirationDuration)),
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'cancelledAt': cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      'expiredAt': expiredAt != null ? Timestamp.fromDate(expiredAt!) : null,
    };
  }

  // UPDATED: Expiration and status helper methods (1 HOUR LOGIC)

  /// Check if request is expired (1 hour limit)
  bool get isExpired {
    if (status == 'expired') return true;
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Check if request is about to expire (15 minutes warning for 1-hour timer)
  bool get isAboutToExpire {
    if (expiresAt == null || !isActive) return false;
    final timeLeft = expiresAt!.difference(DateTime.now());
    return timeLeft.inMinutes <= 15; // 15 minutes warning for 1-hour timer
  }

  /// Check if request is critical (5 minutes left)
  bool get isCritical {
    if (expiresAt == null || !isActive) return false;
    final timeLeft = expiresAt!.difference(DateTime.now());
    return timeLeft.inMinutes <= 5;
  }

  /// Get time remaining until expiration (1 hour total)
  Duration? get timeRemaining {
    if (expiresAt == null || !isActive) return null;
    final now = DateTime.now();
    if (now.isAfter(expiresAt!)) return Duration.zero;
    return expiresAt!.difference(now);
  }

  /// Get formatted time remaining string (for UI display)
  String get timeRemainingString {
    final remaining = timeRemaining;
    if (remaining == null) return 'No expiry';
    if (remaining.inSeconds <= 0) return 'Expired';

    if (remaining.inHours > 0) {
      return '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
    } else {
      return '${remaining.inMinutes}m ${remaining.inSeconds.remainder(60)}s';
    }
  }

  /// Get short formatted time for compact UI
  String get shortTimeRemaining {
    final remaining = timeRemaining;
    if (remaining == null) return '--:--';
    if (remaining.inSeconds <= 0) return '00:00';

    if (remaining.inHours > 0) {
      return '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
    } else {
      final seconds = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '${remaining.inMinutes}m ${seconds}s';
    }
  }

  /// Get progress percentage for circular timer (0.0 to 1.0)
  double get timerProgress {
    if (expiresAt == null || createdAt == null) return 0.0;
    final totalDuration = expiresAt!.difference(createdAt!);
    final elapsed = DateTime.now().difference(createdAt!);

    if (elapsed.inSeconds <= 0) return 0.0;
    if (elapsed.inSeconds >= totalDuration.inSeconds) return 1.0;

    return elapsed.inSeconds / totalDuration.inSeconds;
  }

  /// Get time elapsed since creation
  Duration get timeElapsed {
    if (createdAt == null) return Duration.zero;
    return DateTime.now().difference(createdAt!);
  }

  /// Status check helpers
  bool get isActive => status == 'active' || status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isExpiredStatus => status == 'expired';

  /// Check if request is in history (not active)
  bool get isInHistory => !isActive;

  /// Check if request was successful (completed)
  bool get wasSuccessful => isCompleted;

  /// Check if request failed (expired or cancelled)
  bool get wasUnsuccessful => isExpiredStatus || isCancelled;

  /// Check if request is urgent
  bool get isUrgent => urgency == 'high' || urgency == 'emergency';

  /// Get status color for UI
  Color get statusColor {
    switch (status) {
      case 'active':
      case 'pending':
        if (isCritical) return Colors.red;
        if (isAboutToExpire) return Colors.orange;
        return Colors.green;
      case 'accepted':
        return Colors.blue;
      case 'completed':
        return Colors.purple;
      case 'cancelled':
        return Colors.grey;
      case 'expired':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Get status text for UI
  String get statusText {
    switch (status) {
      case 'active':
      case 'pending':
        if (isCritical) return 'Critical';
        if (isAboutToExpire) return 'Expiring Soon';
        return 'Active';
      case 'accepted':
        return 'Accepted by Donor';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'expired':
        return 'Expired';
      default:
        return 'Unknown';
    }
  }

  /// Get urgency color
  Color get urgencyColor {
    switch (urgency) {
      case 'emergency':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'normal':
        return Colors.blue;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  /// Get urgency icon
  IconData get urgencyIcon {
    switch (urgency) {
      case 'emergency':
        return Icons.warning_amber_rounded;
      case 'high':
        return Icons.error_outline;
      case 'normal':
        return Icons.info_outline;
      case 'low':
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  /// CopyWith method for creating modified copies
  BloodRequest copyWith({
    String? id,
    String? requesterId,
    String? requesterName,
    String? bloodType,
    int? units,
    String? urgency,
    String? city,
    String? address,
    String? hospital,
    String? notes,
    String? phone,
    GeoPoint? location,
    String? status,
    String? acceptedBy,
    String? acceptedByName,
    String? acceptedByType,
    String? acceptedBloodBankName,
    DateTime? createdAt,
    DateTime? neededBy,
    int? searchRadius,
    List<String>? notifiedDonors,
    List<String>? notifiedBloodBanks,
    String? donorToken,
    String? recipientToken,
    double? latitude,
    double? longitude,
    // ✅ ADDED: Potential donors
    List<String>? potentialDonors,
    DateTime? expiresAt,
    DateTime? acceptedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    DateTime? expiredAt,
  }) {
    return BloodRequest(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      bloodType: bloodType ?? this.bloodType,
      units: units ?? this.units,
      urgency: urgency ?? this.urgency,
      city: city ?? this.city,
      address: address ?? this.address,
      hospital: hospital ?? this.hospital,
      notes: notes ?? this.notes,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      status: status ?? this.status,
      acceptedBy: acceptedBy ?? this.acceptedBy,
      acceptedByName: acceptedByName ?? this.acceptedByName,
      acceptedByType: acceptedByType ?? this.acceptedByType,
      acceptedBloodBankName: acceptedBloodBankName ?? this.acceptedBloodBankName,
      createdAt: createdAt ?? this.createdAt,
      neededBy: neededBy ?? this.neededBy,
      searchRadius: searchRadius ?? this.searchRadius,
      notifiedDonors: notifiedDonors ?? this.notifiedDonors,
      notifiedBloodBanks: notifiedBloodBanks ?? this.notifiedBloodBanks,
      donorToken: donorToken ?? this.donorToken,
      recipientToken: recipientToken ?? this.recipientToken,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      // ✅ ADDED: Potential donors
      potentialDonors: potentialDonors ?? this.potentialDonors,
      expiresAt: expiresAt ?? this.expiresAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      expiredAt: expiredAt ?? this.expiredAt,
    );
  }

  /// Get display date based on status
  DateTime get displayDate {
    return completedAt ?? cancelledAt ?? expiredAt ?? acceptedAt ?? createdAt ?? DateTime.now();
  }

  /// Get status description for history
  String get historyStatus {
    if (isCompleted) return 'Donation Completed';
    if (isAccepted) return 'Accepted by Donor';
    if (isExpiredStatus) return 'Request Expired';
    if (isCancelled) return 'Request Cancelled';
    return 'Active Request';
  }

  /// Check if request can be cancelled (only active requests)
  bool get canCancel => isActive;

  /// Check if request can be completed (only accepted requests)
  bool get canComplete => isAccepted;

  /// Check if request can be accepted (only active requests)
  bool get canAccept => isActive;

  // ✅ ADDED: Helper for donor matching
  bool get hasPotentialDonors => potentialDonors.isNotEmpty;

  // ✅ ADDED: Get matching donors count
  int get matchingDonorsCount => potentialDonors.length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is BloodRequest &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'BloodRequest{id: $id, bloodType: $bloodType, status: $status, units: $units, urgency: $urgency, timeRemaining: $timeRemainingString, potentialDonors: $potentialDonors}';
  }
}