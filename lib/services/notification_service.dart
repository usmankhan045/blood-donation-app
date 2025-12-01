import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/blood_request_model.dart';
import '../models/blood_bank_model.dart';
import '../models/donor_model.dart';
import 'fcm_service.dart';
import 'blood_compatibility_service.dart';
import 'dart:math';

/// 🚀 PROFESSIONAL NOTIFICATION SERVICE FOR BLOOD BANKS & DONORS
/// Handles FCM notifications with blood type matching + location filtering
/// Also writes to Firestore user_notifications for in-app notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static NotificationService get instance => _instance;

  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final FCMService _fcmService = FCMService();

  // ═══════════════════════════════════════════════════════════════
  // 📥 WRITE NOTIFICATION TO FIRESTORE USER_NOTIFICATIONS
  // This is CRITICAL for in-app notification delivery
  // ═══════════════════════════════════════════════════════════════

  Future<void> _writeNotificationToInbox({
    required String userId,
    required String title,
    required String body,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _fs
          .collection('user_notifications')
          .doc(userId)
          .collection('inbox')
          .add({
            'title': title,
            'body': body,
            'type': type,
            'requestId': data['requestId'] ?? '',
            'bloodType': data['bloodType'] ?? '',
            'urgency': data['urgency'] ?? '',
            'distance': data['distance'] ?? '',
            'requesterId': data['requesterId'] ?? '',
            'requesterName': data['requesterName'] ?? '',
            'targetType': data['targetType'] ?? '',
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
            'data': data,
          });
      print('📥 Notification written to inbox for user: $userId');
    } catch (e) {
      print('❌ Error writing notification to inbox: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 🩸 DONOR NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════

  Future<List<String>> notifyCompatibleDonors(BloodRequest request) async {
    try {
      print('🩸 ════════════════════════════════════════════════════════');
      print('🩸 FINDING COMPATIBLE DONORS FOR REQUEST ${request.id}');
      print(
        '🩸 Blood Type: ${request.bloodType} | Radius: ${request.searchRadius}km',
      );
      print('🩸 ════════════════════════════════════════════════════════');

      final compatibleTypes = BloodCompatibilityService.getCompatibleDonorTypes(
        request.bloodType,
      );
      print('🎯 Compatible blood types: ${compatibleTypes.join(", ")}');

      final eligibleDonors = await _findEligibleDonors(
        request,
        compatibleTypes,
      );

      if (eligibleDonors.isEmpty) {
        print('❌ No eligible donors found');
        return [];
      }

      print('✅ Found ${eligibleDonors.length} eligible donors');

      final notifiedDonors = <String>[];
      int successCount = 0;
      int failCount = 0;

      for (final donor in eligibleDonors) {
        try {
          final userDoc = await _fs.collection('users').doc(donor.userId).get();
          final fcmToken = userDoc.data()?['fcmToken'] as String?;

          if (fcmToken == null || fcmToken.isEmpty) {
            print('⚠️  Donor ${donor.fullName} has no FCM token');
            failCount++;
            continue;
          }

          final distance = _calculateDistance(
            request.latitude,
            request.longitude,
            donor.latitude,
            donor.longitude,
          );

          final notificationTitle = _getNotificationTitle(
            request.urgency,
            request.bloodType,
          );
          final notificationBody = _getNotificationBody(
            request.bloodType,
            request.units,
            distance,
            request.urgency,
          );
          final notificationData = {
            'type': 'blood_request',
            'requestId': request.id,
            'bloodType': request.bloodType,
            'units': request.units.toString(),
            'urgency': request.urgency,
            'distance': distance.toStringAsFixed(1),
            'requesterId': request.requesterId,
            'requesterName': request.requesterName,
            'targetType': 'donor',
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'timestamp': DateTime.now().toIso8601String(),
          };

          // 🔥 CRITICAL: Write to Firestore inbox for in-app notifications
          await _writeNotificationToInbox(
            userId: donor.userId,
            title: notificationTitle,
            body: notificationBody,
            type: 'blood_request',
            data: notificationData,
          );

          // 🔥 Send FCM push notification
          if (request.urgency == 'emergency') {
            await _fcmService.sendEmergencyNotification(
              token: fcmToken,
              bloodType: request.bloodType,
              distance: distance,
              units: request.units,
              requestId: request.id,
            );
          } else {
            await _fcmService.sendNotificationWithBackup(
              token: fcmToken,
              title: notificationTitle,
              body: notificationBody,
              data: notificationData,
            );
          }

          notifiedDonors.add(donor.userId);
          successCount++;

          print(
            '✅ Notified: ${donor.fullName} (${donor.bloodType}) - ${distance.toStringAsFixed(1)}km',
          );

          await Future.delayed(Duration(milliseconds: 100));
        } catch (e) {
          print('❌ Failed to notify ${donor.fullName}: $e');
          failCount++;
        }
      }

      // Update request
      await _fs.collection('blood_requests').doc(request.id).update({
        'notifiedDonors': notifiedDonors,
        'potentialDonors': notifiedDonors,
        'matchingDonorsCount': notifiedDonors.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('🩸 ════════════════════════════════════════════════════════');
      print('✅ DONOR NOTIFICATION SUMMARY:');
      print('   Success: $successCount | Failed: $failCount');
      print('   Total Notified: ${notifiedDonors.length}');
      print('🩸 ════════════════════════════════════════════════════════');

      return notifiedDonors;
    } catch (e) {
      print('❌ Error notifying donors: $e');
      return [];
    }
  }

  Future<List<DonorModel>> _findEligibleDonors(
    BloodRequest request,
    List<String> compatibleTypes,
  ) async {
    try {
      final eligibleDonors = <DonorModel>[];

      for (final bloodType in compatibleTypes) {
        final donorsSnapshot =
            await _fs
                .collection('users')
                .where('role', isEqualTo: 'donor')
                .where('bloodType', isEqualTo: bloodType)
                .where('isAvailable', isEqualTo: true)
                .where('profileCompleted', isEqualTo: true)
                .get();

        for (final doc in donorsSnapshot.docs) {
          try {
            final donor = DonorModel.fromDoc(doc);

            if (!donor.hasValidLocation) {
              print('❌ Donor ${donor.fullName} has invalid location');
              continue;
            }

            final distance = _calculateDistance(
              request.latitude,
              request.longitude,
              donor.latitude,
              donor.longitude,
            );

            if (distance <= request.searchRadius) {
              eligibleDonors.add(donor);
              print(
                '✅ ${donor.fullName} (${donor.bloodType}) - ${distance.toStringAsFixed(1)}km',
              );
            }
          } catch (e) {
            print('❌ Error processing donor ${doc.id}: $e');
          }
        }
      }

      eligibleDonors.sort((a, b) {
        final distA = _calculateDistance(
          request.latitude,
          request.longitude,
          a.latitude,
          a.longitude,
        );
        final distB = _calculateDistance(
          request.latitude,
          request.longitude,
          b.latitude,
          b.longitude,
        );
        return distA.compareTo(distB);
      });

      return eligibleDonors;
    } catch (e) {
      print('❌ Error finding eligible donors: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 🏥 BLOOD BANK NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════

  Future<List<String>> notifyCompatibleBloodBanks(BloodRequest request) async {
    try {
      print('🏥 ════════════════════════════════════════════════════════');
      print('🏥 FINDING COMPATIBLE BLOOD BANKS FOR REQUEST ${request.id}');
      print(
        '🏥 Blood Type: ${request.bloodType} | Radius: ${request.searchRadius}km',
      );
      print('🏥 ════════════════════════════════════════════════════════');

      final eligibleBloodBanks = await _findEligibleBloodBanks(request);

      if (eligibleBloodBanks.isEmpty) {
        print('❌ No eligible blood banks found');
        return [];
      }

      print('✅ Found ${eligibleBloodBanks.length} eligible blood banks');

      final notifiedBloodBanks = <String>[];
      int successCount = 0;
      int failCount = 0;

      for (final bloodBank in eligibleBloodBanks) {
        try {
          final userDoc =
              await _fs.collection('users').doc(bloodBank.uid).get();
          final fcmToken = userDoc.data()?['fcmToken'] as String?;

          if (fcmToken == null || fcmToken.isEmpty) {
            print('⚠️  Blood Bank ${bloodBank.bloodBankName} has no FCM token');
            failCount++;
            continue;
          }

          final distance = _calculateDistance(
            request.latitude,
            request.longitude,
            bloodBank.location!.latitude,
            bloodBank.location!.longitude,
          );

          final notificationTitle = _getNotificationTitle(
            request.urgency,
            request.bloodType,
          );
          final notificationBody = _getNotificationBody(
            request.bloodType,
            request.units,
            distance,
            request.urgency,
          );
          final notificationData = {
            'type': 'blood_request',
            'requestId': request.id,
            'bloodType': request.bloodType,
            'units': request.units.toString(),
            'urgency': request.urgency,
            'distance': distance.toStringAsFixed(1),
            'requesterId': request.requesterId,
            'requesterName': request.requesterName,
            'address': request.address,
            'city': request.city,
            'targetType': 'blood_bank',
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'timestamp': DateTime.now().toIso8601String(),
          };

          // 🔥 CRITICAL: Write to Firestore inbox for in-app notifications
          await _writeNotificationToInbox(
            userId: bloodBank.uid,
            title: notificationTitle,
            body: notificationBody,
            type: 'blood_request',
            data: notificationData,
          );

          // 🔥 Send FCM push notification
          await _fcmService.sendNotificationWithBackup(
            token: fcmToken,
            title: notificationTitle,
            body: notificationBody,
            data: notificationData,
          );

          notifiedBloodBanks.add(bloodBank.uid);
          successCount++;

          print(
            '✅ Notified: ${bloodBank.bloodBankName} (${distance.toStringAsFixed(1)}km)',
          );

          await Future.delayed(Duration(milliseconds: 100));
        } catch (e) {
          print('❌ Failed to notify ${bloodBank.bloodBankName}: $e');
          failCount++;
        }
      }

      await _fs.collection('blood_requests').doc(request.id).update({
        'notifiedBloodBanks': notifiedBloodBanks,
        'notifiedBloodBanksCount': notifiedBloodBanks.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('🏥 ════════════════════════════════════════════════════════');
      print('✅ BLOOD BANK NOTIFICATION SUMMARY:');
      print('   Success: $successCount | Failed: $failCount');
      print('   Total Notified: ${notifiedBloodBanks.length}');
      print('🏥 ════════════════════════════════════════════════════════');

      return notifiedBloodBanks;
    } catch (e) {
      print('❌ Error notifying blood banks: $e');
      return [];
    }
  }

  Future<List<BloodBankModel>> _findEligibleBloodBanks(
    BloodRequest request,
  ) async {
    try {
      // 🔧 FIXED: Use 'role' field (consistent with blood_request_repository)
      // Also query for both isVerified and isActive for broader matching
      final bloodBanksSnapshot =
          await _fs
              .collection('users')
              .where('role', isEqualTo: 'blood_bank')
              .where('profileCompleted', isEqualTo: true)
              .get();

      print(
        '📊 Found ${bloodBanksSnapshot.docs.length} blood banks with completed profiles',
      );

      final eligibleBloodBanks = <BloodBankModel>[];

      for (final doc in bloodBanksSnapshot.docs) {
        try {
          final bloodBank = BloodBankModel.fromFirestore(doc);

          // 🔧 FIXED: Check for either isActive OR isVerified (supports both field names)
          final docData = doc.data();
          final isActive = docData['isActive'] as bool? ?? false;
          final isVerifiedFromDoc =
              docData['isVerified'] as bool? ?? bloodBank.isVerified;

          if (!isActive && !isVerifiedFromDoc) {
            print(
              '❌ Blood Bank ${bloodBank.bloodBankName} is not active/verified',
            );
            continue;
          }

          if (bloodBank.location == null) {
            print('❌ Blood Bank ${bloodBank.bloodBankName} has no location');
            continue;
          }

          final distance = _calculateDistance(
            request.latitude,
            request.longitude,
            bloodBank.location!.latitude,
            bloodBank.location!.longitude,
          );

          final maxDistance = request.searchRadius * 2.0;

          if (distance > maxDistance) {
            print(
              '❌ ${bloodBank.bloodBankName} too far: ${distance.toStringAsFixed(1)}km',
            );
            continue;
          }

          // 🔧 FIXED: Check inventory from both model and subcollection
          bool hasEnoughInventory = false;
          int availableUnits = 0;

          // First check: BloodBankModel inventory (embedded in user document)
          if (bloodBank.inventory.containsKey(request.bloodType)) {
            final inventoryData = bloodBank.inventory[request.bloodType];
            if (inventoryData is Map && inventoryData['units'] != null) {
              availableUnits = (inventoryData['units'] as num).toInt();
              hasEnoughInventory = availableUnits >= request.units;
            }
          }

          // Second check: Subcollection inventory (if first check failed)
          if (!hasEnoughInventory) {
            try {
              final inventoryDoc =
                  await _fs
                      .collection('blood_banks')
                      .doc(bloodBank.uid)
                      .collection('inventory')
                      .doc(request.bloodType)
                      .get();

              if (inventoryDoc.exists) {
                final data = inventoryDoc.data();
                availableUnits =
                    (data?['availableUnits'] as num?)?.toInt() ??
                    (data?['units'] as num?)?.toInt() ??
                    0;
                hasEnoughInventory = availableUnits >= request.units;
              }
            } catch (e) {
              print(
                '⚠️  Could not check subcollection inventory for ${bloodBank.bloodBankName}: $e',
              );
            }
          }

          if (hasEnoughInventory) {
            eligibleBloodBanks.add(bloodBank);
            print(
              '✅ ${bloodBank.bloodBankName} - ${distance.toStringAsFixed(1)}km - Has $availableUnits units',
            );
          } else if (availableUnits > 0) {
            print(
              '⚠️  ${bloodBank.bloodBankName} - Insufficient units: $availableUnits < ${request.units}',
            );
          } else {
            print(
              '❌ ${bloodBank.bloodBankName} - No ${request.bloodType} in inventory',
            );
          }
        } catch (e) {
          print('❌ Error processing blood bank ${doc.id}: $e');
        }
      }

      eligibleBloodBanks.sort((a, b) {
        final distA = _calculateDistance(
          request.latitude,
          request.longitude,
          a.location!.latitude,
          a.location!.longitude,
        );
        final distB = _calculateDistance(
          request.latitude,
          request.longitude,
          b.location!.latitude,
          b.location!.longitude,
        );
        return distA.compareTo(distB);
      });

      return eligibleBloodBanks;
    } catch (e) {
      print('❌ Error finding eligible blood banks: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 🔔 COMBINED NOTIFICATION
  // ═══════════════════════════════════════════════════════════════

  /// Notify all compatible donors and blood banks
  /// Set [bloodBanksOnly] to true for hospital requests (they only notify blood banks)
  Future<Map<String, dynamic>> notifyAll(
    BloodRequest request, {
    bool bloodBanksOnly = false,
  }) async {
    try {
      print('🔔 ════════════════════════════════════════════════════════');
      print(
        '🔔 SENDING NOTIFICATIONS ${bloodBanksOnly ? "TO BLOOD BANKS ONLY" : "TO DONORS & BLOOD BANKS"}',
      );
      print('🔔 Request ID: ${request.id}');
      print('🔔 ════════════════════════════════════════════════════════');

      // 🔧 OPTIMIZATION: Fetch the fresh request from Firestore to get already-matched donors
      // This avoids duplicate querying since BloodRequestRepository already matched them
      BloodRequest freshRequest = request;
      try {
        final requestDoc =
            await _fs.collection('blood_requests').doc(request.id).get();
        if (requestDoc.exists) {
          freshRequest = BloodRequest.fromMap(requestDoc.data()!, request.id);
          print(
            '🔄 Fetched fresh request with ${freshRequest.potentialDonors.length} pre-matched donors',
          );
        }
      } catch (e) {
        print('⚠️  Could not fetch fresh request, using original: $e');
      }

      List<String> notifiedDonors = [];
      List<String> notifiedBloodBanks = [];

      if (bloodBanksOnly) {
        // Hospital requests: only notify blood banks
        notifiedBloodBanks = await notifyCompatibleBloodBanks(freshRequest);
      } else {
        // Recipient requests: notify both donors and blood banks
        final results = await Future.wait([
          notifyCompatibleDonors(freshRequest),
          notifyCompatibleBloodBanks(freshRequest),
        ]);
        notifiedDonors = results[0];
        notifiedBloodBanks = results[1];
      }

      print('🔔 ════════════════════════════════════════════════════════');
      print('✅ COMPLETE NOTIFICATION SUMMARY:');
      print('   Donors Notified: ${notifiedDonors.length}');
      print('   Blood Banks Notified: ${notifiedBloodBanks.length}');
      print('   Total: ${notifiedDonors.length + notifiedBloodBanks.length}');
      print('🔔 ════════════════════════════════════════════════════════');

      return {
        'donorsNotified': notifiedDonors.length,
        'bloodBanksNotified': notifiedBloodBanks.length,
        'totalNotified': notifiedDonors.length + notifiedBloodBanks.length,
        'donorIds': notifiedDonors,
        'bloodBankIds': notifiedBloodBanks,
        'success': true,
      };
    } catch (e) {
      print('❌ Error in notifyAll: $e');
      return {
        'donorsNotified': 0,
        'bloodBanksNotified': 0,
        'totalNotified': 0,
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Notify only blood banks (for hospital requests)
  Future<Map<String, dynamic>> notifyBloodBanksOnly(
    BloodRequest request,
  ) async {
    return notifyAll(request, bloodBanksOnly: true);
  }

  // ═══════════════════════════════════════════════════════════════
  // 🚀 OPTIMIZED NOTIFICATION - Uses pre-matched donors from request
  // ═══════════════════════════════════════════════════════════════

  /// Notify donors using the pre-matched potentialDonors array from request
  /// This is more efficient than re-querying all donors
  Future<List<String>> notifyPreMatchedDonors(BloodRequest request) async {
    try {
      if (request.potentialDonors.isEmpty) {
        print('⚠️  No pre-matched donors, falling back to full query');
        return notifyCompatibleDonors(request);
      }

      print('🚀 Using ${request.potentialDonors.length} pre-matched donors');

      final notifiedDonors = <String>[];
      int successCount = 0;
      int failCount = 0;

      for (final donorId in request.potentialDonors) {
        try {
          final userDoc = await _fs.collection('users').doc(donorId).get();
          if (!userDoc.exists) continue;

          final userData = userDoc.data()!;
          final fcmToken = userData['fcmToken'] as String?;
          final donorName = userData['fullName'] as String? ?? 'Donor';
          final donorBloodType = userData['bloodType'] as String? ?? '';

          if (fcmToken == null || fcmToken.isEmpty) {
            print('⚠️  Donor $donorName has no FCM token');
            failCount++;
            continue;
          }

          // Calculate distance
          double distance = 0;
          if (userData['location'] is GeoPoint) {
            final loc = userData['location'] as GeoPoint;
            distance = _calculateDistance(
              request.latitude,
              request.longitude,
              loc.latitude,
              loc.longitude,
            );
          }

          final notificationTitle = _getNotificationTitle(
            request.urgency,
            request.bloodType,
          );
          final notificationBody = _getNotificationBody(
            request.bloodType,
            request.units,
            distance,
            request.urgency,
          );
          final notificationData = {
            'type': 'blood_request',
            'requestId': request.id,
            'bloodType': request.bloodType,
            'units': request.units.toString(),
            'urgency': request.urgency,
            'distance': distance.toStringAsFixed(1),
            'requesterId': request.requesterId,
            'requesterName': request.requesterName,
            'targetType': 'donor',
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'timestamp': DateTime.now().toIso8601String(),
          };

          // Write to Firestore inbox
          await _writeNotificationToInbox(
            userId: donorId,
            title: notificationTitle,
            body: notificationBody,
            type: 'blood_request',
            data: notificationData,
          );

          // Send FCM push
          if (request.urgency == 'emergency') {
            await _fcmService.sendEmergencyNotification(
              token: fcmToken,
              bloodType: request.bloodType,
              distance: distance,
              units: request.units,
              requestId: request.id,
            );
          } else {
            await _fcmService.sendNotificationWithBackup(
              token: fcmToken,
              title: notificationTitle,
              body: notificationBody,
              data: notificationData,
            );
          }

          notifiedDonors.add(donorId);
          successCount++;
          print(
            '✅ Notified: $donorName ($donorBloodType) - ${distance.toStringAsFixed(1)}km',
          );
        } catch (e) {
          print('❌ Failed to notify donor $donorId: $e');
          failCount++;
        }
      }

      print(
        '🚀 Pre-matched notification: $successCount success, $failCount failed',
      );
      return notifiedDonors;
    } catch (e) {
      print('❌ Error in notifyPreMatchedDonors: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 🛠️ HELPER METHODS
  // ═══════════════════════════════════════════════════════════════

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371;
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  String _getNotificationTitle(String urgency, String bloodType) {
    switch (urgency) {
      case 'emergency':
        return '🚨 EMERGENCY: $bloodType Blood Needed!';
      case 'high':
        return '⚠️ URGENT: $bloodType Blood Required';
      case 'normal':
        return '🩸 Blood Request: $bloodType Needed';
      default:
        return '🩸 Blood Request: $bloodType Needed';
    }
  }

  String _getNotificationBody(
    String bloodType,
    int units,
    double distance,
    String urgency,
  ) {
    final distanceStr = distance.toStringAsFixed(1);
    final urgencyStr =
        urgency == 'emergency'
            ? 'IMMEDIATELY'
            : urgency == 'high'
            ? 'urgently'
            : '';
    return '$bloodType blood needed $urgencyStr - ${distanceStr}km away. $units unit(s) required. Tap to respond.';
  }

  // ═══════════════════════════════════════════════════════════════
  // 🧪 TESTING
  // ═══════════════════════════════════════════════════════════════

  Future<void> sendTestNotification(String userId, String userType) async {
    try {
      final userDoc = await _fs.collection('users').doc(userId).get();
      final fcmToken = userDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null) {
        print('❌ No FCM token for user $userId');
        return;
      }

      await _fcmService.sendNotification(
        token: fcmToken,
        title: '🧪 Test Notification',
        body:
            'This is a test notification for $userType. Your notifications are working!',
        data: {
          'type': 'test',
          'userType': userType,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      print('✅ Test notification sent to $userId');
    } catch (e) {
      print('❌ Error sending test notification: $e');
    }
  }
}

final notificationService = NotificationService.instance;
