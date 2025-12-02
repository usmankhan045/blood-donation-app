import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/blood_request_model.dart';
import '../../../repositories/blood_request_repository.dart';
import '../../../services/fulfillment_service.dart';
import '../../../widgets/modern_request_card.dart';
import '../../../widgets/custom_snackbar.dart';
import '../../../core/theme.dart';
import '../../chat/chat_screen.dart';

// ═══════════════════════════════════════════════════════════════
// 🩸 PENDING INVENTORY DEDUCTION CARD
// Shows when requester marks donation complete and blood bank
// needs to confirm/decline inventory deduction
// ═══════════════════════════════════════════════════════════════

class PendingInventoryDeductionCard extends StatelessWidget {
  final Map<String, dynamic> deduction;
  final VoidCallback onConfirm;
  final VoidCallback onDecline;

  const PendingInventoryDeductionCard({
    super.key,
    required this.deduction,
    required this.onConfirm,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final bloodType = deduction['bloodType'] as String? ?? '';
    final units = (deduction['units'] as num?)?.toInt() ?? 0;
    final requesterName = deduction['requesterName'] as String? ?? 'Requester';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFE53935)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.inventory_2,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🩸 Inventory Deduction Required',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Donation completed by $requesterName',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        bloodType,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Blood Type',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  Column(
                    children: [
                      Text(
                        '$units',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Unit${units > 1 ? 's' : ''} to Deduct',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDecline,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Decline'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: onConfirm,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Confirm & Deduct'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: BloodAppTheme.error,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BloodBankRequestsScreen extends StatefulWidget {
  const BloodBankRequestsScreen({super.key});

  @override
  State<BloodBankRequestsScreen> createState() => _BloodBankRequestsScreenState();
}

class _BloodBankRequestsScreenState extends State<BloodBankRequestsScreen>
    with SingleTickerProviderStateMixin {
  final _repo = BloodRequestRepository.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BloodAppTheme.background,
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildAvailableRequests(),
          _buildAcceptedRequests(),
          _buildHistory(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: BloodAppTheme.primary,
      foregroundColor: Colors.white,
      title: const Text(
        'Blood Requests',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      bottom: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(
            icon: Icon(Icons.notifications_active, size: 22),
            text: 'Available',
          ),
          Tab(
            icon: Icon(Icons.check_circle, size: 22),
            text: 'Accepted',
          ),
          Tab(
            icon: Icon(Icons.history, size: 22),
            text: 'History',
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableRequests() {
    return StreamBuilder<List<BloodRequest>>(
      stream: _repo.getAvailableRequestsForBloodBank(_uid),
      builder: (context, requestsSnapshot) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: FulfillmentService.instance.getPendingInventoryDeductions(_uid),
          builder: (context, deductionsSnapshot) {
            if (requestsSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }

            if (requestsSnapshot.hasError) {
              return _buildErrorState('Error loading requests');
            }

            final requests = requestsSnapshot.data ?? [];
            final activeRequests = requests.where((r) => !r.isExpired).toList();
            final pendingDeductions = deductionsSnapshot.data ?? [];

            if (activeRequests.isEmpty && pendingDeductions.isEmpty) {
              return _buildEmptyState(
                icon: Icons.inbox_outlined,
                title: 'No Active Requests',
                subtitle: 'You\'ll be notified when new requests\nmatch your inventory.',
              );
            }

            return RefreshIndicator(
              onRefresh: () async => setState(() {}),
              color: BloodAppTheme.primary,
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.only(bottom: 20),
                children: [
                  // Pending inventory deductions (urgent - show first)
                  if (pendingDeductions.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber, color: BloodAppTheme.error, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'ACTION REQUIRED (${pendingDeductions.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: BloodAppTheme.error,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...pendingDeductions.map((deduction) => PendingInventoryDeductionCard(
                      deduction: deduction,
                      onConfirm: () => _confirmInventoryDeduction(deduction),
                      onDecline: () => _declineInventoryDeduction(deduction),
                    )),
                    const Divider(height: 32),
                  ],

                  // Stats header
                  if (activeRequests.isNotEmpty) _buildStatsHeader(activeRequests),

                  // Active requests
                  ...activeRequests.map((request) => ModernRequestCard(
                    request: request,
                    isRecipientView: false,
                    onAccept: () => _acceptRequest(request),
                    onDecline: () => _declineRequest(request),
                    onViewDetails: () => _showRequestDetails(request),
                    showActions: true,
                  )),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmInventoryDeduction(Map<String, dynamic> deduction) async {
    final requestId = deduction['requestId'] as String;
    final bloodType = deduction['bloodType'] as String? ?? '';
    final units = (deduction['units'] as num?)?.toInt() ?? 0;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BloodAppTheme.radiusLg),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: BloodAppTheme.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inventory_2, color: BloodAppTheme.success),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Confirm Deduction?')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will deduct $units unit(s) of $bloodType from your inventory.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BloodAppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: BloodAppTheme.warning, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. Make sure the blood was actually provided.',
                      style: TextStyle(fontSize: 12, color: BloodAppTheme.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: BloodAppTheme.success),
            child: const Text('Confirm & Deduct'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final success = await FulfillmentService.instance.confirmInventoryDeduction(
        requestId: requestId,
      );

      if (mounted) {
        if (success) {
          AppSnackbar.showSuccess(
            context,
            'Inventory Updated! 🩸',
            subtitle: '$units unit(s) of $bloodType deducted from inventory',
          );
        } else {
          AppSnackbar.showError(context, 'Failed to update inventory');
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Error: ${e.toString()}');
      }
    }
  }

  Future<void> _declineInventoryDeduction(Map<String, dynamic> deduction) async {
    final requestId = deduction['requestId'] as String;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BloodAppTheme.radiusLg),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: BloodAppTheme.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: BloodAppTheme.error),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Decline Deduction?')),
          ],
        ),
        content: const Text(
          'If you decline, the inventory will NOT be deducted. '
          'Only decline if the blood was not actually provided from your stock.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: BloodAppTheme.error),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final success = await FulfillmentService.instance.declineInventoryDeduction(
        requestId: requestId,
        reason: 'Blood bank declined deduction',
      );

      if (mounted) {
        if (success) {
          AppSnackbar.showInfo(
            context,
            'Deduction Declined',
            subtitle: 'Inventory was not modified',
          );
        } else {
          AppSnackbar.showError(context, 'Failed to decline');
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Error: ${e.toString()}');
      }
    }
  }

  Widget _buildAcceptedRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('blood_requests')
          .where('acceptedBy', isEqualTo: _uid)
          .where('acceptedByType', isEqualTo: 'blood_bank')
          .where('status', isEqualTo: 'accepted')
          .orderBy('acceptedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState('Error loading requests');
        }

        final requests = snapshot.data?.docs
                .map((doc) => BloodRequest.fromMap(
                    doc.data() as Map<String, dynamic>, doc.id))
                .toList() ??
            [];

        if (requests.isEmpty) {
          return _buildEmptyState(
            icon: Icons.check_circle_outline,
            title: 'No Accepted Requests',
            subtitle: 'Accepted requests will appear here.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          color: BloodAppTheme.primary,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return ModernRequestCard(
                request: request,
                isRecipientView: false,
                onComplete: () => _showFulfillmentConfirmation(request),
                onChat: () => _openChat(request),
                onViewDetails: () => _showRequestDetails(request),
                showActions: true,
                showTimer: false,
              );
            },
          ),
        );
      },
    );
  }

  void _openChat(BloodRequest request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          threadId: request.id,
          title: request.requesterName,
          subtitle: '${request.bloodType} Blood Request - ${request.units} unit(s)',
          otherUserName: request.requesterName,
          otherUserId: request.requesterId,
          bloodType: request.bloodType,
          units: request.units,
        ),
      ),
    );
  }

  Future<void> _showFulfillmentConfirmation(BloodRequest request) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BloodAppTheme.radiusLg),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: BloodAppTheme.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inventory_2, color: BloodAppTheme.success),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Confirm Fulfillment'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Did you fulfill this blood request?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BloodAppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.water_drop, color: BloodAppTheme.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '${request.bloodType} - ${request.units} unit(s)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: BloodAppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'For: ${request.requesterName}',
                    style: TextStyle(
                      fontSize: 12,
                      color: BloodAppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BloodAppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: BloodAppTheme.warning, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Confirming will automatically deduct the units from your inventory.',
                      style: TextStyle(fontSize: 12, color: BloodAppTheme.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'decline'),
            style: OutlinedButton.styleFrom(
              foregroundColor: BloodAppTheme.error,
              side: const BorderSide(color: BloodAppTheme.error),
            ),
            child: const Text('Not Fulfilled'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'confirm'),
            style: ElevatedButton.styleFrom(backgroundColor: BloodAppTheme.success),
            child: const Text('Confirm & Deduct'),
          ),
        ],
      ),
    );

    if (result == 'confirm') {
      await _confirmFulfillment(request);
    } else if (result == 'decline') {
      await _declineFulfillment(request);
    }
  }

  Future<void> _confirmFulfillment(BloodRequest request) async {
    try {
      final success = await FulfillmentService.instance.confirmFulfillment(
        requestId: request.id,
        bloodBankId: _uid,
        bloodType: request.bloodType,
        units: request.units,
      );

      if (mounted) {
        if (success) {
          AppSnackbar.showSuccess(
            context,
            'Request completed! 🎉',
            subtitle: '${request.units} units of ${request.bloodType} deducted from inventory',
          );
          _tabController.animateTo(2);
        } else {
          AppSnackbar.showError(context, 'Failed to complete request');
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Error: ${e.toString()}');
      }
    }
  }

  Future<void> _declineFulfillment(BloodRequest request) async {
    try {
      final success = await FulfillmentService.instance.declineFulfillment(
        requestId: request.id,
        bloodBankId: _uid,
        reason: 'Request could not be fulfilled',
      );

      if (mounted) {
        if (success) {
          AppSnackbar.showInfo(
            context,
            'Request released',
            subtitle: 'The request is now available for others',
          );
        } else {
          AppSnackbar.showError(context, 'Failed to release request');
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Error: ${e.toString()}');
      }
    }
  }

  Widget _buildHistory() {
    // Show both completed/accepted requests AND declined requests
    return StreamBuilder<List<List<BloodRequest>>>(
      stream: _getHistoryRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState('Error loading history');
        }

        final data = snapshot.data ?? [[], []];
        final completedRequests = data[0];
        final declinedRequests = data[1];
        
        // Combine and sort by date
        final allRequests = [...completedRequests, ...declinedRequests];
        allRequests.sort((a, b) {
          final aTime = a.completedAt ?? a.createdAt;
          final bTime = b.completedAt ?? b.createdAt;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        if (allRequests.isEmpty) {
          return _buildEmptyState(
            icon: Icons.history,
            title: 'No History',
            subtitle: 'Completed and declined requests\nwill appear here.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          color: BloodAppTheme.primary,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: allRequests.length,
            itemBuilder: (context, index) {
              final request = allRequests[index];
              final isDeclined = declinedRequests.any((r) => r.id == request.id);
              
              return Stack(
                children: [
                  ModernRequestCard(
                    request: request,
                    isRecipientView: false,
                    onViewDetails: () => _showRequestDetails(request),
                    showActions: false,
                    showTimer: false,
                  ),
                  // Show "Declined" badge for declined requests
                  if (isDeclined)
                    Positioned(
                      top: 16,
                      right: 24,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: BloodAppTheme.error,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'DECLINED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // Combine completed and declined requests into one stream
  Stream<List<List<BloodRequest>>> _getHistoryRequests() {
    // Stream 1: Completed/cancelled/expired requests that this blood bank accepted
    final completedStream = FirebaseFirestore.instance
        .collection('blood_requests')
        .where('acceptedBy', isEqualTo: _uid)
        .where('acceptedByType', isEqualTo: 'blood_bank')
        .where('status', whereIn: ['completed', 'cancelled', 'expired'])
        .orderBy('updatedAt', descending: true)
        .limit(25)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BloodRequest.fromMap(doc.data(), doc.id))
            .toList());

    // Stream 2: Declined requests
    final declinedStream = _repo.getDeclinedRequestsForBloodBank(_uid);

    // Combine both streams
    return completedStream.asyncMap((completed) async {
      final declined = await declinedStream.first;
      return [completed, declined];
    });
  }

  Widget _buildStatsHeader(List<BloodRequest> requests) {
    final urgent = requests.where((r) => r.urgency == 'emergency' || r.urgency == 'high').length;
    final expiring = requests.where((r) => r.isAboutToExpire).length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [BloodAppTheme.primary, BloodAppTheme.primaryDark],
        ),
        borderRadius: BorderRadius.circular(BloodAppTheme.radiusLg),
        boxShadow: BloodAppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Available Requests',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${requests.length} total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatBadge('Total', requests.length, Colors.white),
              const SizedBox(width: 12),
              _buildStatBadge('Urgent', urgent, BloodAppTheme.accent),
              const SizedBox(width: 12),
              _buildStatBadge('Expiring', expiring, BloodAppTheme.warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BloodAppTheme.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              color: color == Colors.white ? BloodAppTheme.primary : color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: BloodAppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(BloodAppTheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading requests...',
            style: TextStyle(color: BloodAppTheme.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: BloodAppTheme.error.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: BloodAppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: BloodAppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: BloodAppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 56,
                color: BloodAppTheme.primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: BloodAppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(color: BloodAppTheme.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _declineRequest(BloodRequest request) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BloodAppTheme.radiusLg),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: BloodAppTheme.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: BloodAppTheme.error),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Decline Request?'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Blood Type: ${request.bloodType}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Requester: ${request.requesterName}'),
            Text('Units: ${request.units}'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BloodAppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: BloodAppTheme.warning, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This request will be removed from your available list and moved to history. Other blood banks can still accept it.',
                      style: TextStyle(fontSize: 12, color: BloodAppTheme.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: BloodAppTheme.error),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _repo.declineRequestByBloodBank(request.id, _uid);

      if (mounted) {
        AppSnackbar.showInfo(
          context,
          'Request declined',
          subtitle: 'This request has been moved to your history',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Failed to decline request', subtitle: e.toString());
      }
    }
  }

  Future<void> _acceptRequest(BloodRequest request) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .get();
    final bloodBankName = userDoc.data()?['bloodBankName'] ?? 'Blood Bank';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BloodAppTheme.radiusLg),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: BloodAppTheme.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: BloodAppTheme.success),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Accept Request?'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Blood Type: ${request.bloodType}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Requester: ${request.requesterName}'),
            Text('Units: ${request.units}'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BloodAppTheme.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: BloodAppTheme.info, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This request will be assigned to your blood bank.',
                      style: TextStyle(fontSize: 12, color: BloodAppTheme.info),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: BloodAppTheme.success),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _repo.acceptRequestByBloodBank(request.id, _uid, bloodBankName);

      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          'Request accepted successfully!',
          subtitle: 'Contact the recipient to coordinate',
        );
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Failed to accept request', subtitle: e.toString());
      }
    }
  }


  void _showRequestDetails(BloodRequest request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RequestDetailsSheet(request: request),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 📋 REQUEST DETAILS BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════

class _RequestDetailsSheet extends StatelessWidget {
  final BloodRequest request;

  const _RequestDetailsSheet({required this.request});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: BloodAppTheme.cardGradient(request.urgency),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.water_drop,
                        size: 20,
                        color: BloodAppTheme.getBloodTypeColor(request.bloodType),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        request.bloodType,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: BloodAppTheme.getBloodTypeColor(request.bloodType),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    request.statusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Requester', request.requesterName, Icons.person),
                  _buildDetailRow('Units Required', '${request.units} unit(s)', Icons.water_drop),
                  _buildDetailRow('Urgency', request.urgency.toUpperCase(), Icons.priority_high),
                  _buildDetailRow('City', request.city, Icons.location_city),
                  _buildDetailRow('Address', request.address, Icons.location_on),
                  if (request.hospital != null)
                    _buildDetailRow('Hospital', request.hospital!, Icons.local_hospital),
                  if (request.phone != null)
                    _buildDetailRow('Phone', request.phone!, Icons.phone),
                  if (request.notes != null && request.notes!.isNotEmpty)
                    _buildDetailRow('Notes', request.notes!, Icons.note),
                  _buildDetailRow('Status', request.statusText, Icons.info),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: BloodAppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: BloodAppTheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: BloodAppTheme.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: BloodAppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
