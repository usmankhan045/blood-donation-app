import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/blood_request_model.dart';
import '../services/donor_matching_service.dart';
import '../services/service_locator.dart';
import '../repositories/blood_request_repository.dart';

class RequestProvider with ChangeNotifier {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✅ FIXED: Use Service Locator for donor matching
  final DonorMatchingService _donorMatchingService = ServiceLocator.donorMatching;

  final BloodRequestRepository _requestRepository = BloodRequestRepository.instance;

  List<BloodRequest> _requests = [];
  List<BloodRequest> _acceptedRequests = [];
  List<BloodRequest> _availableRequests = [];

  // Real-time timer states for beautiful UI
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, Duration> _requestTimers = {};

  List<BloodRequest> get requests => _requests;
  List<BloodRequest> get acceptedRequests => _acceptedRequests;
  List<BloodRequest> get availableRequests => _availableRequests;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Get timer for specific request
  Duration? getTimerForRequest(String requestId) => _requestTimers[requestId];

  // Real-time streams for beautiful UI updates with timer support
  Stream<List<BloodRequest>> get recipientRequestsStream {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _fs
        .collection('blood_requests')
        .where('requesterId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => BloodRequest.fromMap(doc.data(), doc.id))
        .toList())
        .asBroadcastStream();
  }

  Stream<List<BloodRequest>> get availableRequestsStream {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _fs
        .collection('blood_requests')
        .where('status', isEqualTo: 'pending')
        .where('potentialDonors', arrayContains: uid)
        .orderBy('urgency')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => BloodRequest.fromMap(doc.data(), doc.id))
        .toList())
        .asBroadcastStream();
  }

  // Stream for single request with real-time timer updates
  Stream<BloodRequest?> getRequestStream(String requestId) {
    return _fs
        .collection('blood_requests')
        .doc(requestId)
        .snapshots()
        .map((doc) => doc.exists ? BloodRequest.fromMap(doc.data()!, doc.id) : null)
        .asBroadcastStream();
  }

  // Filter requests by status for beautiful UI
  List<BloodRequest> get activeRequests =>
      _requests.where((request) => request.isActive).toList();

  List<BloodRequest> get acceptedRequestsList =>
      _requests.where((request) => request.isAccepted).toList();

  List<BloodRequest> get completedRequests =>
      _requests.where((request) => request.isCompleted).toList();

  List<BloodRequest> get expiredRequests =>
      _requests.where((request) => request.isExpiredStatus).toList();

  List<BloodRequest> get urgentRequests =>
      _requests.where((request) => request.isUrgent).toList();

  // Get requests that are about to expire (for timer warnings)
  List<BloodRequest> get expiringSoonRequests =>
      _requests.where((request) => request.isAboutToExpire).toList();

  // Get critical requests (less than 5 minutes)
  List<BloodRequest> get criticalRequests =>
      _requests.where((request) => request.isCritical).toList();

  // Fetch requests created by the current user (for recipients) - UPDATED with real-time
  Future<void> fetchMyRequests() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      _setLoading(true);
      _clearError();

      // Use repository method for consistency
      final repositoryStream = _requestRepository.getRecipientRequests(uid);

      // Listen to the stream and update local state
      repositoryStream.listen((requests) {
        _requests = requests;
        _updateRequestTimers(requests);
        notifyListeners();
      }, onError: (error) {
        _setError('Failed to load your requests: $error');
      });

    } catch (e) {
      _setError('Error fetching my requests: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Fetch requests accepted by the current user (for donors) - UPDATED
  Future<void> fetchAcceptedRequests() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      _setLoading(true);
      _clearError();

      final snapshot = await _fs
          .collection('blood_requests')
          .where('acceptedBy', isEqualTo: uid)
          .orderBy('acceptedAt', descending: true)
          .get();

      _acceptedRequests = snapshot.docs.map((doc) {
        return BloodRequest.fromMap(doc.data()!, doc.id);
      }).toList();

      notifyListeners();
    } catch (e) {
      _setError('Error fetching accepted requests: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Fetch available requests for donors - UPDATED with real-time
  Future<void> fetchAvailableRequests() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      _setLoading(true);
      _clearError();

      final repositoryStream = _requestRepository.getAvailableRequestsForDonor(uid);

      repositoryStream.listen((requests) {
        _availableRequests = requests;
        _updateRequestTimers(requests);
        notifyListeners();
      }, onError: (error) {
        _setError('Failed to load available requests: $error');
      });

    } catch (e) {
      _setError('Error fetching available requests: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Update request timers for real-time countdown
  void _updateRequestTimers(List<BloodRequest> requests) {
    final now = DateTime.now();

    for (final request in requests) {
      if (request.isActive && request.expiresAt != null) {
        final timeRemaining = request.expiresAt!.difference(now);
        if (timeRemaining.isNegative) {
          _requestTimers[request.id] = Duration.zero;
        } else {
          _requestTimers[request.id] = timeRemaining;
        }
      } else {
        _requestTimers.remove(request.id);
      }
    }
  }

  // Start timer updates for active requests
  void startTimerUpdates() {
    // Update timers every second for real-time countdown
    Timer.periodic(Duration(seconds: 1), (timer) {
      if (_requests.isNotEmpty || _availableRequests.isNotEmpty) {
        _updateAllTimers();
        notifyListeners();
      }
    });
  }

  void _updateAllTimers() {
    final now = DateTime.now();
    final allRequests = [..._requests, ..._availableRequests];

    for (final request in allRequests) {
      if (request.isActive && request.expiresAt != null) {
        final timeRemaining = request.expiresAt!.difference(now);
        if (timeRemaining.isNegative) {
          _requestTimers[request.id] = Duration.zero;
          // Auto-refresh if request expired
          _handleExpiredRequest(request.id);
        } else {
          _requestTimers[request.id] = timeRemaining;
        }
      }
    }
  }

  // Handle expired requests
  void _handleExpiredRequest(String requestId) {
    // Refresh data to get updated status
    fetchMyRequests();
    fetchAvailableRequests();
  }

  // ✅ FIXED: Create blood request with donor matching using Service Locator
  Future<void> createBloodRequest(BloodRequest request) async {
    try {
      _setLoading(true);
      _clearError();

      print('🚀 Starting blood request creation process...');

      // Use repository for consistent request creation with 1-hour timer
      final requestId = await _requestRepository.createRequest(
        requesterId: request.requesterId,
        requesterName: request.requesterName,
        city: request.city,
        bloodType: request.bloodType,
        urgency: request.urgency,
        units: request.units,
        location: request.location!,
        address: request.address,
        hospital: request.hospital,
        notes: request.notes,
        phone: request.phone,
        neededBy: request.neededBy,
        searchRadius: request.searchRadius,
        expirationMinutes: 60, // 1-HOUR expiration
      );

      print('✅ Blood request created with ID: $requestId');

      // ✅ ADDED: Create updated request with the generated ID
      final updatedRequest = request.copyWith(id: requestId);

      // ✅ FIXED: Use Service Locator for donor matching (without notifications)
      print('🚀 Starting donor matching process...');
      await _donorMatchingService.processMatchingDonors(updatedRequest);

      // Update local state
      await fetchMyRequests();

      print('🎉 Blood request process completed successfully!');

    } catch (e) {
      print('❌ Error in createBloodRequest: $e');
      _setError('Failed to create request: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // SMART ACCEPTANCE - With beautiful UI feedback and real-time updates
  Future<void> acceptRequest(String requestId, String donorId, String donorName) async {
    try {
      _setLoading(true);
      _clearError();

      // Use repository for smart acceptance (removes from other donors)
      await _requestRepository.acceptRequestByDonor(requestId, donorId, donorName);

      // Remove timer for accepted request
      _requestTimers.remove(requestId);

      // Update local state
      await fetchAvailableRequests();
      await fetchAcceptedRequests();

      print('✅ Request $requestId accepted by $donorName - Removed from other donors');

    } catch (e) {
      _setError('Failed to accept request: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Mark a request as completed with beautiful UI feedback
  Future<void> completeRequest(String requestId) async {
    try {
      _setLoading(true);
      _clearError();

      await _requestRepository.completeRequest(requestId);

      // Remove timer for completed request
      _requestTimers.remove(requestId);

      // Update local state
      await fetchMyRequests();
      await fetchAcceptedRequests();

      print('✅ Request $requestId marked as completed');

    } catch (e) {
      _setError('Failed to complete request: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Cancel a blood request with beautiful UI feedback
  Future<void> cancelRequest(String requestId) async {
    try {
      _setLoading(true);
      _clearError();

      await _requestRepository.cancelRequest(requestId);

      // Remove timer for cancelled request
      _requestTimers.remove(requestId);

      await fetchMyRequests();

      print('✅ Request $requestId cancelled');

    } catch (e) {
      _setError('Failed to cancel request: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Get request by ID with real-time updates
  Stream<BloodRequest?> getRequestByIdStream(String requestId) {
    return _fs
        .collection('blood_requests')
        .doc(requestId)
        .snapshots()
        .map((doc) => doc.exists ? BloodRequest.fromMap(doc.data()!, doc.id) : null)
        .asBroadcastStream();
  }

  // Refresh all data for beautiful UI
  Future<void> refreshAllData() async {
    try {
      _setLoading(true);
      _clearError();

      await Future.wait([
        fetchMyRequests(),
        fetchAcceptedRequests(),
        fetchAvailableRequests(),
      ]);
      print('✅ All request data refreshed');
    } catch (e) {
      _setError('Failed to refresh data: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Get statistics for dashboard with expired requests
  Future<Map<String, int>> getRequestStats(String userId) async {
    try {
      final stats = await _requestRepository.getRequestStats(userId, 'recipient');
      return stats;
    } catch (e) {
      print('Error getting request stats: $e');
      return {
        'pending': 0,
        'accepted': 0,
        'completed': 0,
        'expired': 0,
        'total': 0,
      };
    }
  }

  // Get urgent requests count for badge
  int get urgentRequestsCount => urgentRequests.length;

  // Get expiring soon count for notifications
  int get expiringSoonCount => expiringSoonRequests.length;

  // Get critical requests count
  int get criticalRequestsCount => criticalRequests.length;

  // Check if user has any active requests
  bool get hasActiveRequests => activeRequests.isNotEmpty;

  // Check if user has any available requests (for donors)
  bool get hasAvailableRequests => availableRequests.isNotEmpty;

  // Get latest request for quick preview
  BloodRequest? get latestRequest => _requests.isNotEmpty ? _requests.first : null;

  // Get requests that need immediate attention (urgent + expiring soon)
  List<BloodRequest> get priorityRequests {
    return _requests.where((request) {
      return request.isUrgent || request.isAboutToExpire || request.isCritical;
    }).toList();
  }

  // Get active requests with timers for beautiful UI
  List<BloodRequest> get activeRequestsWithTimers {
    return activeRequests.where((request) => _requestTimers.containsKey(request.id)).toList();
  }

  // Loading state management
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  // Clear error manually
  void clearError() {
    _clearError();
    notifyListeners();
  }

  // Clear data when user logs out
  void clearData() {
    _requests.clear();
    _acceptedRequests.clear();
    _availableRequests.clear();
    _requestTimers.clear();
    _clearError();
    _setLoading(false);
    notifyListeners();
  }

  // Initialize provider with timer updates
  void initialize() {
    // ✅ ADDED: Check if ServiceLocator is initialized
    if (!ServiceLocator.isInitialized) {
      print('⚠️ ServiceLocator not initialized - initializing now');
      ServiceLocator().initialize();
    }

    startTimerUpdates();
    fetchMyRequests();
    fetchAvailableRequests();
    fetchAcceptedRequests();
  }

  // Dispose method to clean up streams
  @override
  void dispose() {
    // Clean up any stream subscriptions if needed
    super.dispose();
  }
}