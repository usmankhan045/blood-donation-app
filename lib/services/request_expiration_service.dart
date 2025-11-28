import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service to handle automatic expiration of blood requests after 1 hour
/// This service manages timers and ensures requests expire properly
class RequestExpirationService {
  static final RequestExpirationService _instance = RequestExpirationService._internal();
  factory RequestExpirationService() => _instance;
  RequestExpirationService._internal();

  static RequestExpirationService get instance => _instance;

  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  // Track active expiration timers
  final Map<String, Timer> _expirationTimers = {};

  // Callback for UI updates when requests expire
  VoidCallback? _onRequestExpired;

  // Set callback for UI updates
  void setExpirationCallback(VoidCallback callback) {
    _onRequestExpired = callback;
  }

  /// Start expiration timer for a request (1 HOUR default)
  void startExpirationTimer(String requestId, [int expirationMinutes = 60]) {
    // Cancel existing timer if any
    cancelExpirationTimer(requestId);

    // Create new timer for 1 hour
    final timer = Timer(
      Duration(minutes: expirationMinutes),
          () => _expireRequest(requestId),
    );

    _expirationTimers[requestId] = timer;

    if (kDebugMode) {
      print('🕒 Started $expirationMinutes-minute expiration timer for request: $requestId');
    }
  }

  /// Start expiration timer based on existing request data
  void startExpirationTimerForRequest(String requestId, DateTime expiresAt) {
    final now = DateTime.now();
    final timeUntilExpiration = expiresAt.difference(now);

    // Only start timer if request hasn't expired yet
    if (timeUntilExpiration.isNegative) {
      // Request already expired, expire it immediately
      if (kDebugMode) {
        print('⏰ Request $requestId already expired, expiring now...');
      }
      _expireRequest(requestId);
    } else {
      // Start timer for remaining time
      final timer = Timer(
        timeUntilExpiration,
            () => _expireRequest(requestId),
      );

      _expirationTimers[requestId] = timer;

      if (kDebugMode) {
        print('🕒 Started expiration timer for request: $requestId (expires in ${timeUntilExpiration.inMinutes}m)');
      }
    }
  }

  /// Expire a request manually or via timer
  Future<void> _expireRequest(String requestId) async {
    try {
      // First check if request still exists and is active
      final requestDoc = await _fs.collection('blood_requests').doc(requestId).get();

      if (!requestDoc.exists) {
        if (kDebugMode) {
          print('❌ Request $requestId not found for expiration');
        }
        return;
      }

      final requestData = requestDoc.data()!;
      final currentStatus = requestData['status'] as String? ?? 'pending';

      // Only expire if still active/pending
      if (currentStatus == 'pending' || currentStatus == 'active') {
        await _fs.collection('blood_requests').doc(requestId).update({
          'status': 'expired',
          'expiredAt': FieldValue.serverTimestamp(),
          // Clear potential donors array
          'potentialDonors': [],
        });

        if (kDebugMode) {
          print('⏰ Request $requestId expired automatically after 1 hour');
        }

        // Notify UI about expiration
        _onRequestExpired?.call();

        // ✅ PRESERVED: Mock donor matching for testing
        await _mockDonorMatching(requestId, requestData);

      } else {
        if (kDebugMode) {
          print('ℹ️ Request $requestId already in status: $currentStatus, skipping expiration');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error expiring request $requestId: $e');
      }
    } finally {
      // Clean up timer
      _expirationTimers.remove(requestId);
    }
  }

  /// ✅ PRESERVED: Mock donor matching for testing
  Future<void> _mockDonorMatching(String requestId, Map<String, dynamic> requestData) async {
    try {
      if (kDebugMode) {
        print('🎯 Running mock donor matching for expired request: $requestId');
      }

      // Simulate finding some mock donors
      final mockDonors = [
        'mock_donor_1',
        'mock_donor_2',
        'mock_donor_3'
      ];

      // Update request with mock potential donors for testing
      await _fs.collection('blood_requests').doc(requestId).update({
        'potentialDonors': mockDonors,
        'matchingDonorsCount': mockDonors.length,
        'isMockData': true, // Flag to identify mock data
      });

      if (kDebugMode) {
        print('✅ Mock donor matching completed for request $requestId - Found ${mockDonors.length} mock donors');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in mock donor matching: $e');
      }
    }
  }

  /// Cancel expiration timer for a request (when accepted, completed, etc.)
  void cancelExpirationTimer(String requestId) {
    final timer = _expirationTimers[requestId];
    if (timer != null) {
      timer.cancel();
      _expirationTimers.remove(requestId);

      if (kDebugMode) {
        print('🛑 Cancelled expiration timer for request: $requestId');
      }
    }
  }

  /// Initialize expiration timers for all active requests
  /// This should be called when the app starts to handle requests that were active during app restart
  Future<void> initializeExpirationTimers() async {
    try {
      final activeRequests = await _fs
          .collection('blood_requests')
          .where('status', whereIn: ['pending', 'active'])
          .get();

      if (kDebugMode) {
        print('🔄 Initializing expiration timers for ${activeRequests.docs.length} active requests');
      }

      for (final doc in activeRequests.docs) {
        final requestData = doc.data();
        final requestId = doc.id;
        final expiresAt = requestData['expiresAt'] as Timestamp?;

        if (expiresAt != null) {
          startExpirationTimerForRequest(requestId, expiresAt.toDate());
        } else {
          // For backward compatibility, set default 1-hour expiration
          final createdAt = requestData['createdAt'] as Timestamp?;
          if (createdAt != null) {
            final defaultExpiresAt = createdAt.toDate().add(Duration(hours: 1));
            startExpirationTimerForRequest(requestId, defaultExpiresAt);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing expiration timers: $e');
      }
    }
  }

  /// Get time remaining for a specific request
  Future<Duration?> getTimeRemaining(String requestId) async {
    try {
      final requestDoc = await _fs.collection('blood_requests').doc(requestId).get();

      if (!requestDoc.exists) return null;

      final requestData = requestDoc.data()!;
      final expiresAt = requestData['expiresAt'] as Timestamp?;
      final status = requestData['status'] as String? ?? 'pending';

      if (expiresAt == null || (status != 'pending' && status != 'active')) return null;

      final now = DateTime.now();
      final expirationTime = expiresAt.toDate();
      final timeRemaining = expirationTime.difference(now);

      return timeRemaining.isNegative ? Duration.zero : timeRemaining;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting time remaining for request $requestId: $e');
      }
      return null;
    }
  }

  /// Check if a request is about to expire (for UI warnings)
  Future<bool> isAboutToExpire(String requestId, [int warningMinutes = 15]) async {
    final timeRemaining = await getTimeRemaining(requestId);
    if (timeRemaining == null) return false;

    return timeRemaining.inMinutes <= warningMinutes && timeRemaining.inSeconds > 0;
  }

  /// Check if a request is critical (less than 5 minutes)
  Future<bool> isCritical(String requestId) async {
    return await isAboutToExpire(requestId, 5);
  }

  /// Get all active timer IDs (for debugging)
  List<String> get activeTimerIds => _expirationTimers.keys.toList();

  /// Get timer count (for debugging)
  int get activeTimerCount => _expirationTimers.length;

  /// Cancel all active timers (on logout or app close)
  void cancelAllTimers() {
    if (kDebugMode) {
      print('🛑 Cancelling all ${_expirationTimers.length} expiration timers');
    }

    for (final timer in _expirationTimers.values) {
      timer.cancel();
    }
    _expirationTimers.clear();
  }

  /// Dispose the service and clean up resources
  void dispose() {
    cancelAllTimers();
    _onRequestExpired = null;
  }

  /// Restart timer for a request (useful when app comes to foreground)
  Future<void> restartTimer(String requestId) async {
    try {
      final requestDoc = await _fs.collection('blood_requests').doc(requestId).get();

      if (!requestDoc.exists) return;

      final requestData = requestDoc.data()!;
      final status = requestData['status'] as String? ?? 'pending';
      final expiresAt = requestData['expiresAt'] as Timestamp?;

      if ((status == 'pending' || status == 'active') && expiresAt != null) {
        startExpirationTimerForRequest(requestId, expiresAt.toDate());
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error restarting timer for request $requestId: $e');
      }
    }
  }

  /// Restart all timers (when app comes to foreground)
  Future<void> restartAllTimers() async {
    try {
      final activeRequests = await _fs
          .collection('blood_requests')
          .where('status', whereIn: ['pending', 'active'])
          .get();

      for (final doc in activeRequests.docs) {
        final requestData = doc.data();
        final requestId = doc.id;
        final expiresAt = requestData['expiresAt'] as Timestamp?;

        if (expiresAt != null) {
          startExpirationTimerForRequest(requestId, expiresAt.toDate());
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error restarting all timers: $e');
      }
    }
  }
}