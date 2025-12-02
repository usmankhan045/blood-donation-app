import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/blood_request_model.dart';
import '../../../repositories/blood_request_repository.dart';
import '../../../widgets/modern_request_card.dart';
import '../../../widgets/custom_snackbar.dart';
import '../../../core/theme.dart';
import '../../chat/chat_screen.dart';

/// 🏥 HOSPITAL MY REQUESTS SCREEN
/// Shows all blood requests made by the hospital
class HospitalMyRequestsScreen extends StatefulWidget {
  const HospitalMyRequestsScreen({super.key});

  @override
  State<HospitalMyRequestsScreen> createState() =>
      _HospitalMyRequestsScreenState();
}

class _HospitalMyRequestsScreenState extends State<HospitalMyRequestsScreen>
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
          _buildActiveTab(),
          _buildAcceptedTab(),
          _buildHistoryTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/hospital/request'),
        backgroundColor: BloodAppTheme.accent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Request',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: BloodAppTheme.primary,
      foregroundColor: Colors.white,
      title: const Text(
        'My Blood Requests',
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
          Tab(icon: Icon(Icons.pending_actions, size: 22), text: 'Active'),
          Tab(icon: Icon(Icons.check_circle, size: 22), text: 'Accepted'),
          Tab(icon: Icon(Icons.history, size: 22), text: 'History'),
        ],
      ),
    );
  }

  Widget _buildActiveTab() {
    return StreamBuilder<List<BloodRequest>>(
      stream: _repo.getRecipientRequests(_uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState('Error loading requests');
        }

        final allRequests = snapshot.data ?? [];
        final activeRequests = allRequests
            .where((r) =>
                (r.status == 'pending' || r.status == 'active') && !r.isExpired)
            .toList()
          ..sort((a, b) {
            // Sort by urgency first, then by creation time
            final urgencyOrder = {'emergency': 0, 'high': 1, 'normal': 2};
            final aOrder = urgencyOrder[a.urgency] ?? 2;
            final bOrder = urgencyOrder[b.urgency] ?? 2;
            if (aOrder != bOrder) return aOrder.compareTo(bOrder);
            final aDate = a.createdAt ?? DateTime.now();
            final bDate = b.createdAt ?? DateTime.now();
            return bDate.compareTo(aDate);
          });

        if (activeRequests.isEmpty) {
          return _buildEmptyState(
            icon: Icons.inbox_outlined,
            title: 'No Active Requests',
            subtitle: 'Create a new blood request to\nnotify blood banks in your area.',
            showButton: true,
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
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: activeRequests.length,
                  itemBuilder: (context, index) {
                    final request = activeRequests[index];
                    return ModernRequestCard(
                      request: request,
                      isRecipientView: true,
                      onCancel: () => _cancelRequest(request),
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

  Widget _buildAcceptedTab() {
    return StreamBuilder<List<BloodRequest>>(
      stream: _repo.getRecipientRequests(_uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState('Error loading requests');
        }

        final allRequests = snapshot.data ?? [];
        final acceptedRequests =
            allRequests.where((r) => r.status == 'accepted').toList()
              ..sort((a, b) {
                final aDate = a.createdAt ?? DateTime.now();
                final bDate = b.createdAt ?? DateTime.now();
                return bDate.compareTo(aDate);
              });

        if (acceptedRequests.isEmpty) {
          return _buildEmptyState(
            icon: Icons.check_circle_outline,
            title: 'No Accepted Requests',
            subtitle: 'When a blood bank accepts your\nrequest, it will appear here.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          color: BloodAppTheme.primary,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: acceptedRequests.length,
            itemBuilder: (context, index) {
              final request = acceptedRequests[index];
              return ModernRequestCard(
                request: request,
                isRecipientView: true,
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

  Widget _buildHistoryTab() {
    return StreamBuilder<List<BloodRequest>>(
      stream: _repo.getRecipientRequests(_uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState('Error loading history');
        }

        final allRequests = snapshot.data ?? [];
        final historyRequests = allRequests
            .where((r) =>
                r.status == 'completed' ||
                r.status == 'expired' ||
                r.status == 'cancelled' ||
                r.isExpired)
            .toList()
          ..sort((a, b) {
            final aDate = a.createdAt ?? DateTime.now();
            final bDate = b.createdAt ?? DateTime.now();
            return bDate.compareTo(aDate);
          });

        if (historyRequests.isEmpty) {
          return _buildEmptyState(
            icon: Icons.history,
            title: 'No History',
            subtitle: 'Completed and expired requests\nwill appear here.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          color: BloodAppTheme.primary,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: historyRequests.length,
            itemBuilder: (context, index) {
              final request = historyRequests[index];
              return ModernRequestCard(
                request: request,
                isRecipientView: true,
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
    final urgent = requests
        .where((r) => r.urgency == 'emergency' || r.urgency == 'high')
        .length;
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
              const Icon(Icons.local_hospital, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Hospital Requests',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${requests.length} active',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Requests sent to blood banks only',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatBadge('Total', requests.length, Colors.white),
              const SizedBox(width: 12),
              _buildStatBadge('Urgent', urgent, BloodAppTheme.error),
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
    bool showButton = false,
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
            if (showButton) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, '/hospital/request'),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Create Request',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BloodAppTheme.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openChat(BloodRequest request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          threadId: request.id,
          title: request.acceptedBloodBankName ?? 'Blood Bank',
          subtitle: '${request.bloodType} Blood Request - ${request.units} unit(s)',
          otherUserName: request.acceptedBloodBankName,
          otherUserId: request.acceptedBy,
          bloodType: request.bloodType,
          units: request.units,
        ),
      ),
    );
  }

  Future<void> _cancelRequest(BloodRequest request) async {
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
              child: const Icon(Icons.cancel, color: BloodAppTheme.error),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Cancel Request?'),
            ),
          ],
        ),
        content: const Text('Are you sure you want to cancel this request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, Keep It'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: BloodAppTheme.error),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _repo.cancelRequest(request.id);
      if (mounted) {
        AppSnackbar.showSuccess(context, 'Request cancelled successfully');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Failed to cancel request');
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
      height: MediaQuery.of(context).size.height * 0.75,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          color:
                              BloodAppTheme.getBloodTypeColor(request.bloodType),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  _buildDetailRow(
                    'Units Required',
                    '${request.units} unit(s)',
                    Icons.water_drop,
                  ),
                  _buildDetailRow(
                    'Urgency',
                    request.urgency.toUpperCase(),
                    Icons.priority_high,
                  ),
                  _buildDetailRow('City', request.city, Icons.location_city),
                  _buildDetailRow('Address', request.address, Icons.location_on),
                  if (request.acceptedByName != null)
                    _buildDetailRow(
                      'Accepted By',
                      request.acceptedByName!,
                      Icons.business,
                    ),
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
                  style:
                      TextStyle(fontSize: 12, color: BloodAppTheme.textSecondary),
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

