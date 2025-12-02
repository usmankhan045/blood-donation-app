import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/blood_request_model.dart';
import '../../../widgets/modern_request_card.dart';
import '../../../widgets/custom_snackbar.dart';
import '../../../core/theme.dart';
import '../../chat/chat_screen.dart';

class RecipientMyRequestsScreen extends StatefulWidget {
  const RecipientMyRequestsScreen({super.key});

  @override
  State<RecipientMyRequestsScreen> createState() => _RecipientMyRequestsScreenState();
}

class _RecipientMyRequestsScreenState extends State<RecipientMyRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'all';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<BloodRequest>>? _requestsStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeStream();
  }

  void _initializeStream() {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      _requestsStream = _firestore
          .collection('blood_requests')
          .where('requesterId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => BloodRequest.fromDoc(doc))
              .toList());
    }
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
          _buildCurrentRequestsTab(),
          _buildHistoryTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/recipient/request'),
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
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(() => _initializeStream()),
          tooltip: 'Refresh',
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        tabs: const [
          Tab(
            icon: Icon(Icons.pending_actions, size: 22),
            text: 'Active',
          ),
          Tab(
            icon: Icon(Icons.history, size: 22),
            text: 'History',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentRequestsTab() {
    return StreamBuilder<List<BloodRequest>>(
      stream: _requestsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState('Error loading requests');
        }

        final allRequests = snapshot.data ?? [];
        
        // Filter for current (active + accepted) and not expired
        final currentRequests = allRequests
            .where((r) => (r.isActive || r.isAccepted) && !r.isExpired)
            .toList();
        
        final filteredRequests = _filterRequests(currentRequests, isHistory: false);

        if (currentRequests.isEmpty) {
          return _buildEmptyState(
            icon: Icons.bloodtype_outlined,
            title: 'No Active Requests',
            subtitle: 'Create a blood request to find\ndonors in your area.',
            showCreateButton: true,
          );
        }

        return Column(
          children: [
            // Stats Header
            _buildStatsHeader(currentRequests),

            // Filter Chips
            _buildFilterChips(isHistory: false),

            // Request List
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => setState(() => _initializeStream()),
                color: BloodAppTheme.primary,
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: filteredRequests.length,
                  itemBuilder: (context, index) {
                    final request = filteredRequests[index];
                    return ModernRequestCard(
                      request: request,
                      isRecipientView: true,
                      onCancel: request.isActive ? () => _cancelRequest(request) : null,
                      onComplete: request.isAccepted ? () => _completeRequest(request) : null,
                      onViewDetails: () => _showRequestDetails(request),
                      onChat: request.isAccepted ? () => _openChat(request) : null,
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

  Widget _buildHistoryTab() {
    return StreamBuilder<List<BloodRequest>>(
      stream: _requestsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState('Error loading history');
        }

        final allRequests = snapshot.data ?? [];
        
        // Filter for history (completed, expired, cancelled)
        final historyRequests = allRequests
            .where((r) => r.isCompleted || r.isExpiredStatus || r.isCancelled || r.isExpired)
            .toList();
        
        final filteredRequests = _filterRequests(historyRequests, isHistory: true);

        if (historyRequests.isEmpty) {
          return _buildEmptyState(
            icon: Icons.history,
            title: 'No History Yet',
            subtitle: 'Your completed, expired, and cancelled\nrequests will appear here.',
          );
        }

        return Column(
          children: [
            // History Stats
            _buildHistoryStats(historyRequests),

            // Filter Chips
            _buildFilterChips(isHistory: true),

            // Request List
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => setState(() => _initializeStream()),
                color: BloodAppTheme.primary,
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: filteredRequests.length,
                  itemBuilder: (context, index) {
                    final request = filteredRequests[index];
                    return ModernRequestCard(
                      request: request,
                      isRecipientView: true,
                      onViewDetails: () => _showRequestDetails(request),
                      showActions: false,
                      showTimer: false,
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

  Widget _buildStatsHeader(List<BloodRequest> requests) {
    final active = requests.where((r) => r.isActive).length;
    final accepted = requests.where((r) => r.isAccepted).length;
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
              const Icon(Icons.pending_actions, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Current Requests',
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
              _buildStatBadge('Active', active, BloodAppTheme.warning),
              const SizedBox(width: 12),
              _buildStatBadge('Accepted', accepted, BloodAppTheme.success),
              const SizedBox(width: 12),
              _buildStatBadge('Expiring', expiring, BloodAppTheme.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryStats(List<BloodRequest> requests) {
    final completed = requests.where((r) => r.isCompleted).length;
    final expired = requests.where((r) => r.isExpiredStatus || r.isExpired).length;
    final cancelled = requests.where((r) => r.isCancelled).length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BloodAppTheme.radiusLg),
        boxShadow: BloodAppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: BloodAppTheme.textSecondary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Request History',
                style: TextStyle(
                  color: BloodAppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHistoryStatItem(Icons.check_circle, completed, 'Completed', BloodAppTheme.success),
              _buildHistoryStatItem(Icons.timer_off, expired, 'Expired', BloodAppTheme.error),
              _buildHistoryStatItem(Icons.cancel, cancelled, 'Cancelled', BloodAppTheme.textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryStatItem(IconData icon, int count, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: BloodAppTheme.textSecondary,
          ),
        ),
      ],
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
              color: color,
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

  Widget _buildFilterChips({required bool isHistory}) {
    final filters = isHistory
        ? ['all', 'completed', 'expired', 'cancelled']
        : ['all', 'active', 'accepted', 'expiring'];

    final filterLabels = {
      'all': 'All',
      'active': 'Active',
      'accepted': 'Accepted',
      'expiring': 'Expiring',
      'completed': 'Completed',
      'expired': 'Expired',
      'cancelled': 'Cancelled',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(
                  filterLabels[filter]!,
                  style: TextStyle(
                    color: isSelected ? Colors.white : BloodAppTheme.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _selectedFilter = filter);
                },
                backgroundColor: Colors.white,
                selectedColor: BloodAppTheme.primary,
                checkmarkColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? BloodAppTheme.primary : Colors.grey.shade300,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
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
              onPressed: () => setState(() => _initializeStream()),
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
    bool showCreateButton = false,
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
            if (showCreateButton) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/recipient/request'),
                icon: const Icon(Icons.add),
                label: const Text('Create Request'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BloodAppTheme.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<BloodRequest> _filterRequests(List<BloodRequest> requests, {required bool isHistory}) {
    if (_selectedFilter == 'all') return requests;

    return requests.where((request) {
      switch (_selectedFilter) {
        case 'active':
          return request.isActive;
        case 'accepted':
          return request.isAccepted;
        case 'expiring':
          return request.isAboutToExpire || request.isCritical;
        case 'completed':
          return request.isCompleted;
        case 'expired':
          return request.isExpiredStatus || request.isExpired;
        case 'cancelled':
          return request.isCancelled;
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _cancelRequest(BloodRequest request) async {
    final confirmed = await showDialog<bool>(
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
                color: BloodAppTheme.warning.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cancel, color: BloodAppTheme.warning),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Cancel Request?'),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to cancel this blood request? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Request'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: BloodAppTheme.warning),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('blood_requests').doc(request.id).update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          AppSnackbar.showSuccess(context, 'Request cancelled successfully');
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.showError(context, 'Failed to cancel request', subtitle: e.toString());
        }
      }
    }
  }

  Future<void> _completeRequest(BloodRequest request) async {
    final confirmed = await showDialog<bool>(
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
            const Expanded(
              child: Text('Complete Request?'),
            ),
          ],
        ),
        content: const Text(
          'Confirm that you have received the blood donation. This will mark the request as completed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: BloodAppTheme.success),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('blood_requests').doc(request.id).update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          AppSnackbar.showSuccess(
            context,
            'Request completed! 🎉',
            subtitle: 'Thank you for using LifeDrop',
          );
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.showError(context, 'Failed to complete request');
        }
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

  void _openChat(BloodRequest request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          threadId: request.id,
          title: request.acceptedByName ?? request.acceptedBloodBankName ?? 'Donor',
          subtitle: '${request.bloodType} Blood Request - ${request.units} unit(s)',
          otherUserName: request.acceptedByName ?? request.acceptedBloodBankName,
          otherUserId: request.acceptedBy,
          bloodType: request.bloodType,
          units: request.units,
        ),
      ),
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
                  _buildDetailRow('Created', _formatDateTime(request.createdAt), Icons.access_time),
                  if (request.acceptedByName != null)
                    _buildDetailRow('Accepted By', request.acceptedByName!, Icons.person),
                  if (request.acceptedAt != null)
                    _buildDetailRow('Accepted At', _formatDateTime(request.acceptedAt), Icons.check),
                  if (request.completedAt != null)
                    _buildDetailRow('Completed At', _formatDateTime(request.completedAt), Icons.verified),
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

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
