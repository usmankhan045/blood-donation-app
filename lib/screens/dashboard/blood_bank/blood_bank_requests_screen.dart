import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/blood_request_model.dart';
import '../../../repositories/blood_request_repository.dart';
import '../../../widgets/modern_request_card.dart';
import '../../../widgets/custom_snackbar.dart';
import '../../../core/theme.dart';
import 'dart:async';

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
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _updateTimer?.cancel();
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
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState('Error loading requests');
        }

        final requests = snapshot.data ?? [];
        final activeRequests = requests.where((r) => !r.isExpired).toList();

        if (activeRequests.isEmpty) {
          return _buildEmptyState(
            icon: Icons.inbox_outlined,
            title: 'No Active Requests',
            subtitle: 'You\'ll be notified when new requests\nmatch your inventory.',
          );
        }

        return Column(
          children: [
            _buildStatsHeader(activeRequests),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => setState(() {}),
                color: BloodAppTheme.primary,
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: activeRequests.length,
                  itemBuilder: (context, index) {
                    final request = activeRequests[index];
                    return ModernRequestCard(
                      request: request,
                      isRecipientView: false,
                      onAccept: () => _acceptRequest(request),
                      onViewDetails: () => _showRequestDetails(request),
                      showActions: true,
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
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
                onComplete: () => _completeRequest(request),
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

  Widget _buildHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('blood_requests')
          .where('acceptedBy', isEqualTo: _uid)
          .where('acceptedByType', isEqualTo: 'blood_bank')
          .where('status', whereIn: ['completed', 'cancelled', 'expired'])
          .orderBy('updatedAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState('Error loading history');
        }

        final requests = snapshot.data?.docs
                .map((doc) => BloodRequest.fromMap(
                    doc.data() as Map<String, dynamic>, doc.id))
                .toList() ??
            [];

        if (requests.isEmpty) {
          return _buildEmptyState(
            icon: Icons.history,
            title: 'No History',
            subtitle: 'Completed requests will appear here.',
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
                onViewDetails: () => _showRequestDetails(request),
                showActions: false,
                showTimer: false,
              );
            },
          ),
        );
      },
    );
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
            const Text('Accept Request?'),
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

  Future<void> _completeRequest(BloodRequest request) async {
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
              child: const Icon(Icons.check_circle, color: BloodAppTheme.success),
            ),
            const SizedBox(width: 12),
            const Text('Complete Request?'),
          ],
        ),
        content: const Text('Mark this request as completed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: BloodAppTheme.success),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _repo.completeRequest(request.id);

      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          'Request completed! 🎉',
          subtitle: 'Thank you for saving a life',
        );
        _tabController.animateTo(2);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Failed to complete request', subtitle: e.toString());
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
