import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'fcm_service.dart';

/// 🏥 FULFILLMENT SERVICE FOR BLOOD BANKS
/// Handles post-acceptance flow:
/// 1. Schedules fulfillment reminder after acceptance
/// 2. Sends notification asking blood bank to confirm fulfillment
/// 3. Deducts inventory when fulfillment is confirmed
class FulfillmentService {
  static final FulfillmentService _instance = FulfillmentService._internal();
  factory FulfillmentService() => _instance;
  FulfillmentService._internal();

  static FulfillmentService get instance => _instance;

  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final FCMService _fcmService = FCMService();

  // Active timers for fulfillment reminders
  final Map<String, Timer> _fulfillmentTimers = {};

  // ═══════════════════════════════════════════════════════════════
  // 📢 SCHEDULE FULFILLMENT REMINDER
  // Called when blood bank accepts a request
  // ═══════════════════════════════════════════════════════════════

  /// Schedule a fulfillment reminder for the blood bank
  /// [reminderDelayMinutes] - Time to wait before sending reminder (default: 30 min)
  void scheduleFulfillmentReminder({
    required String requestId,
    required String bloodBankId,
    required String bloodType,
    required int units,
    required String requesterName,
    int reminderDelayMinutes = 30,
  }) {
    // Cancel any existing timer for this request
    _fulfillmentTimers[requestId]?.cancel();

    print('⏰ Scheduling fulfillment reminder for request $requestId in $reminderDelayMinutes minutes');

    // Schedule the reminder
    _fulfillmentTimers[requestId] = Timer(
      Duration(minutes: reminderDelayMinutes),
      () => _sendFulfillmentReminder(
        requestId: requestId,
        bloodBankId: bloodBankId,
        bloodType: bloodType,
        units: units,
        requesterName: requesterName,
      ),
    );

    // Also save the pending fulfillment to Firestore for persistence
    _savePendingFulfillment(
      requestId: requestId,
      bloodBankId: bloodBankId,
      bloodType: bloodType,
      units: units,
      requesterName: requesterName,
      reminderAt: DateTime.now().add(Duration(minutes: reminderDelayMinutes)),
    );
  }

  /// Save pending fulfillment to Firestore
  Future<void> _savePendingFulfillment({
    required String requestId,
    required String bloodBankId,
    required String bloodType,
    required int units,
    required String requesterName,
    required DateTime reminderAt,
  }) async {
    try {
      await _fs.collection('pending_fulfillments').doc(requestId).set({
        'requestId': requestId,
        'bloodBankId': bloodBankId,
        'bloodType': bloodType,
        'units': units,
        'requesterName': requesterName,
        'status': 'pending',
        'reminderAt': Timestamp.fromDate(reminderAt),
        'createdAt': FieldValue.serverTimestamp(),
        'reminderSent': false,
      });
      print('✅ Pending fulfillment saved for request $requestId');
    } catch (e) {
      print('❌ Error saving pending fulfillment: $e');
    }
  }

  /// Send fulfillment reminder notification to blood bank
  Future<void> _sendFulfillmentReminder({
    required String requestId,
    required String bloodBankId,
    required String bloodType,
    required int units,
    required String requesterName,
  }) async {
    try {
      print('📢 Sending fulfillment reminder for request $requestId');

      // Get blood bank FCM token
      final userDoc = await _fs.collection('users').doc(bloodBankId).get();
      final fcmToken = userDoc.data()?['fcmToken'] as String?;
      final bloodBankName = userDoc.data()?['bloodBankName'] as String? ?? 'Blood Bank';

      if (fcmToken == null || fcmToken.isEmpty) {
        print('⚠️ Blood bank $bloodBankName has no FCM token');
        return;
      }

      final notificationTitle = '🩸 Fulfillment Confirmation Required';
      final notificationBody = 'Did you fulfill the $bloodType blood request ($units units) for $requesterName? Please confirm to update your inventory.';

      final notificationData = {
        'type': 'fulfillment_reminder',
        'requestId': requestId,
        'bloodType': bloodType,
        'units': units.toString(),
        'requesterName': requesterName,
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Write to Firestore inbox for in-app notification
      await _writeNotificationToInbox(
        userId: bloodBankId,
        title: notificationTitle,
        body: notificationBody,
        type: 'fulfillment_reminder',
        data: notificationData,
      );

      // Send FCM push notification
      await _fcmService.sendNotificationWithBackup(
        token: fcmToken,
        title: notificationTitle,
        body: notificationBody,
        data: notificationData,
      );

      // Update pending fulfillment status
      await _fs.collection('pending_fulfillments').doc(requestId).update({
        'reminderSent': true,
        'reminderSentAt': FieldValue.serverTimestamp(),
      });

      print('✅ Fulfillment reminder sent to $bloodBankName');

      // Remove from active timers
      _fulfillmentTimers.remove(requestId);

    } catch (e) {
      print('❌ Error sending fulfillment reminder: $e');
    }
  }

  /// Write notification to user inbox
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
            'units': data['units'] ?? '',
            'requesterName': data['requesterName'] ?? '',
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
            'data': data,
          });
    } catch (e) {
      print('❌ Error writing notification to inbox: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ CONFIRM FULFILLMENT & DEDUCT INVENTORY
  // Called when blood bank confirms the request was fulfilled
  // ═══════════════════════════════════════════════════════════════

  /// Confirm fulfillment and deduct inventory
  /// Returns true if successful, false otherwise
  Future<bool> confirmFulfillment({
    required String requestId,
    required String bloodBankId,
    required String bloodType,
    required int units,
  }) async {
    try {
      print('✅ Confirming fulfillment for request $requestId');

      // Start a batch write for atomic operation
      final batch = _fs.batch();

      // 1. Update the blood request status to completed
      final requestRef = _fs.collection('blood_requests').doc(requestId);
      batch.update(requestRef, {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'fulfilledBy': bloodBankId,
        'fulfilledUnits': units,
        'inventoryDeducted': true,
      });

      // 2. Deduct inventory from blood bank
      final userRef = _fs.collection('users').doc(bloodBankId);
      
      // Get current inventory first
      final userDoc = await userRef.get();
      if (!userDoc.exists) {
        throw Exception('Blood bank not found');
      }

      final userData = userDoc.data()!;
      final inventory = Map<String, dynamic>.from(userData['inventory'] ?? {});
      
      if (!inventory.containsKey(bloodType)) {
        throw Exception('Blood type $bloodType not in inventory');
      }

      final bloodTypeData = inventory[bloodType] as Map<String, dynamic>;
      final currentUnits = (bloodTypeData['units'] as num?)?.toInt() ?? 0;
      final newUnits = (currentUnits - units).clamp(0, currentUnits);

      // Update inventory
      batch.update(userRef, {
        'inventory.$bloodType.units': newUnits,
        'inventory.$bloodType.lastUpdated': FieldValue.serverTimestamp(),
        'inventory.$bloodType.lastDeductedAt': FieldValue.serverTimestamp(),
        'inventory.$bloodType.lastDeductedUnits': units,
        'inventory.$bloodType.lastDeductedReason': 'Blood request fulfillment',
      });

      // 3. Update pending fulfillment status
      final fulfillmentRef = _fs.collection('pending_fulfillments').doc(requestId);
      batch.update(fulfillmentRef, {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'inventoryDeducted': true,
        'deductedUnits': units,
        'previousUnits': currentUnits,
        'newUnits': newUnits,
      });

      // 4. Create inventory transaction record
      final transactionRef = _fs.collection('inventory_transactions').doc();
      batch.set(transactionRef, {
        'bloodBankId': bloodBankId,
        'bloodType': bloodType,
        'type': 'deduction',
        'units': units,
        'previousUnits': currentUnits,
        'newUnits': newUnits,
        'reason': 'Request fulfillment',
        'requestId': requestId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Commit the batch
      await batch.commit();

      print('✅ Fulfillment confirmed: $bloodType inventory updated from $currentUnits to $newUnits units');

      // Cancel any pending timer
      cancelFulfillmentReminder(requestId);

      return true;
    } catch (e) {
      print('❌ Error confirming fulfillment: $e');
      return false;
    }
  }

  /// Decline fulfillment (request was not fulfilled)
  Future<bool> declineFulfillment({
    required String requestId,
    required String bloodBankId,
    String? reason,
  }) async {
    try {
      print('❌ Declining fulfillment for request $requestId');

      // Update the pending fulfillment
      await _fs.collection('pending_fulfillments').doc(requestId).update({
        'status': 'declined',
        'declinedAt': FieldValue.serverTimestamp(),
        'declineReason': reason ?? 'Not fulfilled',
      });

      // Update the request status back to pending so others can accept
      await _fs.collection('blood_requests').doc(requestId).update({
        'status': 'pending',
        'acceptedBy': FieldValue.delete(),
        'acceptedByType': FieldValue.delete(),
        'acceptedBloodBankName': FieldValue.delete(),
        'acceptedAt': FieldValue.delete(),
        'declinedBy': FieldValue.arrayUnion([bloodBankId]),
        'lastDeclinedAt': FieldValue.serverTimestamp(),
        'declineReason': reason ?? 'Not fulfilled',
      });

      // Cancel any pending timer
      cancelFulfillmentReminder(requestId);

      return true;
    } catch (e) {
      print('❌ Error declining fulfillment: $e');
      return false;
    }
  }

  /// Cancel a scheduled fulfillment reminder
  void cancelFulfillmentReminder(String requestId) {
    _fulfillmentTimers[requestId]?.cancel();
    _fulfillmentTimers.remove(requestId);
  }

  // ═══════════════════════════════════════════════════════════════
  // 🔄 CHECK PENDING FULFILLMENTS ON APP START
  // Resume any pending fulfillment reminders
  // ═══════════════════════════════════════════════════════════════

  /// Check and process any pending fulfillments
  Future<void> processPendingFulfillments() async {
    try {
      print('🔄 Checking for pending fulfillments...');

      final now = DateTime.now();
      
      // Get pending fulfillments that haven't been reminded yet
      final pendingDocs = await _fs
          .collection('pending_fulfillments')
          .where('status', isEqualTo: 'pending')
          .where('reminderSent', isEqualTo: false)
          .get();

      for (final doc in pendingDocs.docs) {
        final data = doc.data();
        final reminderAt = (data['reminderAt'] as Timestamp?)?.toDate();
        
        if (reminderAt != null) {
          if (reminderAt.isBefore(now)) {
            // Reminder time has passed, send immediately
            await _sendFulfillmentReminder(
              requestId: data['requestId'],
              bloodBankId: data['bloodBankId'],
              bloodType: data['bloodType'],
              units: data['units'],
              requesterName: data['requesterName'],
            );
          } else {
            // Schedule for later
            final delay = reminderAt.difference(now);
            _fulfillmentTimers[data['requestId']] = Timer(
              delay,
              () => _sendFulfillmentReminder(
                requestId: data['requestId'],
                bloodBankId: data['bloodBankId'],
                bloodType: data['bloodType'],
                units: data['units'],
                requesterName: data['requesterName'],
              ),
            );
          }
        }
      }

      print('✅ Processed ${pendingDocs.docs.length} pending fulfillments');
    } catch (e) {
      print('❌ Error processing pending fulfillments: $e');
    }
  }

  /// Get pending fulfillments for a blood bank
  Stream<List<Map<String, dynamic>>> getPendingFulfillmentsForBloodBank(String bloodBankId) {
    return _fs
        .collection('pending_fulfillments')
        .where('bloodBankId', isEqualTo: bloodBankId)
        .where('status', isEqualTo: 'pending')
        .where('reminderSent', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {
          ...doc.data(),
          'id': doc.id,
        }).toList());
  }

  // ═══════════════════════════════════════════════════════════════
  // 🩸 INVENTORY DEDUCTION CONFIRMATION FLOW
  // Called when REQUESTER marks donation as complete
  // Blood bank then confirms/declines the inventory deduction
  // ═══════════════════════════════════════════════════════════════

  /// Request inventory deduction confirmation from blood bank
  /// Called when requester marks donation as complete
  Future<void> requestInventoryDeductionConfirmation({
    required String requestId,
    required String bloodBankId,
    required String bloodType,
    required int units,
    required String requesterName,
  }) async {
    try {
      print('📢 Requesting inventory deduction confirmation from blood bank');

      // Get blood bank info
      final userDoc = await _fs.collection('users').doc(bloodBankId).get();
      final fcmToken = userDoc.data()?['fcmToken'] as String?;
      final bloodBankName = userDoc.data()?['bloodBankName'] as String? ?? 'Blood Bank';

      // Create pending inventory deduction record
      await _fs.collection('pending_inventory_deductions').doc(requestId).set({
        'requestId': requestId,
        'bloodBankId': bloodBankId,
        'bloodBankName': bloodBankName,
        'bloodType': bloodType,
        'units': units,
        'requesterName': requesterName,
        'status': 'pending', // pending, confirmed, declined
        'createdAt': FieldValue.serverTimestamp(),
      });

      final notificationTitle = '🩸 Inventory Deduction Required';
      final notificationBody = 'Donation completed! $units unit(s) of $bloodType blood for $requesterName. Please confirm to deduct from your inventory.';

      final notificationData = {
        'type': 'inventory_deduction_request',
        'requestId': requestId,
        'bloodType': bloodType,
        'units': units.toString(),
        'requesterName': requesterName,
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Write to Firestore inbox for in-app notification
      await _writeNotificationToInbox(
        userId: bloodBankId,
        title: notificationTitle,
        body: notificationBody,
        type: 'inventory_deduction_request',
        data: notificationData,
      );

      // Send FCM push notification
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await _fcmService.sendNotificationWithBackup(
          token: fcmToken,
          title: notificationTitle,
          body: notificationBody,
          data: notificationData,
        );
      }

      print('✅ Inventory deduction confirmation request sent to $bloodBankName');
    } catch (e) {
      print('❌ Error requesting inventory deduction confirmation: $e');
      rethrow;
    }
  }

  /// Confirm inventory deduction (blood bank accepts)
  Future<bool> confirmInventoryDeduction({
    required String requestId,
  }) async {
    try {
      print('✅ Blood bank confirming inventory deduction for request $requestId');

      // Get the pending deduction record
      final deductionDoc = await _fs.collection('pending_inventory_deductions').doc(requestId).get();
      if (!deductionDoc.exists) {
        throw Exception('Pending deduction not found');
      }

      final data = deductionDoc.data()!;
      final bloodBankId = data['bloodBankId'] as String;
      final bloodType = data['bloodType'] as String;
      final units = (data['units'] as num).toInt();

      // Start a batch write for atomic operation
      final batch = _fs.batch();

      // 1. Update the pending deduction status
      final deductionRef = _fs.collection('pending_inventory_deductions').doc(requestId);
      batch.update(deductionRef, {
        'status': 'confirmed',
        'confirmedAt': FieldValue.serverTimestamp(),
      });

      // 2. Update blood request with inventory deduction info
      final requestRef = _fs.collection('blood_requests').doc(requestId);
      batch.update(requestRef, {
        'inventoryDeducted': true,
        'inventoryDeductedAt': FieldValue.serverTimestamp(),
      });

      // 3. Deduct inventory from blood bank
      final userRef = _fs.collection('users').doc(bloodBankId);
      
      // Get current inventory first
      final userDoc = await userRef.get();
      if (!userDoc.exists) {
        throw Exception('Blood bank not found');
      }

      final userData = userDoc.data()!;
      final inventory = Map<String, dynamic>.from(userData['inventory'] ?? {});
      
      int currentUnits = 0;
      int newUnits = 0;

      if (inventory.containsKey(bloodType)) {
        final bloodTypeData = inventory[bloodType] as Map<String, dynamic>;
        currentUnits = (bloodTypeData['units'] as num?)?.toInt() ?? 0;
        newUnits = (currentUnits - units).clamp(0, currentUnits);

        // Update inventory
        batch.update(userRef, {
          'inventory.$bloodType.units': newUnits,
          'inventory.$bloodType.lastUpdated': FieldValue.serverTimestamp(),
          'inventory.$bloodType.lastDeductedAt': FieldValue.serverTimestamp(),
          'inventory.$bloodType.lastDeductedUnits': units,
          'inventory.$bloodType.lastDeductedReason': 'Donation completed',
        });
      } else {
        // Blood type not in inventory, just log it
        print('⚠️ Blood type $bloodType not found in inventory, skipping deduction');
      }

      // 4. Create inventory transaction record
      final transactionRef = _fs.collection('inventory_transactions').doc();
      batch.set(transactionRef, {
        'bloodBankId': bloodBankId,
        'bloodType': bloodType,
        'type': 'deduction',
        'units': units,
        'previousUnits': currentUnits,
        'newUnits': newUnits,
        'reason': 'Donation completed',
        'requestId': requestId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Commit the batch
      await batch.commit();

      print('✅ Inventory deduction confirmed: $bloodType updated from $currentUnits to $newUnits units');

      return true;
    } catch (e) {
      print('❌ Error confirming inventory deduction: $e');
      return false;
    }
  }

  /// Decline inventory deduction (blood bank rejects)
  Future<bool> declineInventoryDeduction({
    required String requestId,
    String? reason,
  }) async {
    try {
      print('❌ Blood bank declining inventory deduction for request $requestId');

      await _fs.collection('pending_inventory_deductions').doc(requestId).update({
        'status': 'declined',
        'declinedAt': FieldValue.serverTimestamp(),
        'declineReason': reason ?? 'Blood bank declined deduction',
      });

      // Update request to indicate no deduction
      await _fs.collection('blood_requests').doc(requestId).update({
        'inventoryDeducted': false,
        'inventoryDeclinedAt': FieldValue.serverTimestamp(),
        'inventoryDeclineReason': reason ?? 'Blood bank declined deduction',
      });

      return true;
    } catch (e) {
      print('❌ Error declining inventory deduction: $e');
      return false;
    }
  }

  /// Get pending inventory deductions for a blood bank
  Stream<List<Map<String, dynamic>>> getPendingInventoryDeductions(String bloodBankId) {
    return _fs
        .collection('pending_inventory_deductions')
        .where('bloodBankId', isEqualTo: bloodBankId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {
          ...doc.data(),
          'id': doc.id,
        }).toList());
  }
}

final fulfillmentService = FulfillmentService.instance;

