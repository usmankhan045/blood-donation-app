import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/blood_request_model.dart';
import '../../../widgets/modern_request_card.dart';
import '../../../widgets/custom_snackbar.dart';
import '../../../core/theme.dart';
import '../../../services/donor_matching_service.dart';
import '../../../repositories/blood_request_repository.dart';
import '../../chat/chat_screen.dart';

class DonorRequestsScreen extends StatefulWidget {
  const DonorRequestsScreen({super.key});

  @override
  State<DonorRequestsScreen> createState() => _DonorRequestsScreenState();
}

class _DonorRequestsScreenState extends State<DonorRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'all';

  final DonorMatchingService _donorMatchingService = DonorMatchingService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<BloodRequest>>? _incomingRequestsStream;
  Stream<List<BloodRequest>>? _acceptedRequestsStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeStreams();
  }

  void _initializeStreams() {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      // Stream for available requests (only pending, not expired)
      _incomingRequestsStream = _firestore
          .collection('blood_requests')
          .where('potentialDonors', arrayContains: userId)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .map((snapshot) {
            final requests =
                snapshot.docs
                    .map((doc) => BloodRequest.fromDoc(doc))
                    .where(
                      (request) => !request.isExpired,
                    ) // Filter out expired
                    .toList();
            // Sort by createdAt on client side to avoid index issues
            requests.sort((a, b) => (b.createdAt ?? DateTime.now())
                .compareTo(a.createdAt ?? DateTime.now()));
            print('📬 Available requests: ${requests.length}');
            return requests;
          });

      // 🔧 FIX: Stream for accepted requests - simplified query without orderBy
      // Filter by acceptedBy and acceptedByType='donor' to only get donor's accepted requests
      _acceptedRequestsStream = _firestore
          .collection('blood_requests')
          .where('acceptedBy', isEqualTo: userId)
          .where('acceptedByType', isEqualTo: 'donor')
          .snapshots()
          .map((snapshot) {
            final requests = snapshot.docs
                .map((doc) => BloodRequest.fromDoc(doc))
                .toList();
            // Sort by acceptedAt on client side to avoid index issues
            requests.sort((a, b) => (b.acceptedAt ?? DateTime.now())
                .compareTo(a.acceptedAt ?? DateTime.now()));
            print('📋 My accepted requests: ${requests.length}');
            return requests;
          });
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
          _buildAvailableRequestsTab(),
          _buildAcceptedRequestsTab(),
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
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            setState(() {
              _initializeStreams();
            });
          },
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
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
        tabs: const [
          Tab(
            icon: Icon(Icons.notifications_active, size: 20),
            text: 'Available',
          ),
          Tab(icon: Icon(Icons.handshake, size: 20), text: 'My Accepted'),
        ],
      ),
    );
  }

  Widget _buildAvailableRequestsTab() {
    final userId = _auth.currentUser?.uid;
    if (userId == null || _incomingRequestsStream == null) {
      return _buildErrorState('Please log in to view requests');
    }

    return StreamBuilder<List<BloodRequest>>(
      stream: _incomingRequestsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState('Error: ${snapshot.error}');
        }

        final requests = snapshot.data ?? [];
        final filteredRequests = _filterRequests(requests);

        if (filteredRequests.isEmpty) {
          return _buildEmptyState(
            icon: Icons.bloodtype_outlined,
            title: 'No Available Requests',
            subtitle:
                'When someone needs your blood type,\nrequests will appear here automatically.',
            showRefresh: true,
          );
        }

        return Column(
          children: [
            // Stats Header
            _buildStatsHeader(requests),

            // Filter Chips
            _buildFilterChips(),

            // Request List
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  setState(() => _initializeStreams());
                },
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
                      isRecipientView: false,
                      onAccept: () => _acceptRequest(request),
                      onDecline: () => _declineRequest(request),
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

  Widget _buildAcceptedRequestsTab() {
    final userId = _auth.currentUser?.uid;
    if (userId == null || _acceptedRequestsStream == null) {
      return _buildErrorState('Please log in to view requests');
    }

    return StreamBuilder<List<BloodRequest>>(
      stream: _acceptedRequestsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState('Error loading accepted requests');
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return _buildEmptyState(
            icon: Icons.check_circle_outline,
            title: 'No Accepted Requests',
            subtitle:
                'Requests you accept will appear here.\nComplete them after donation.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _initializeStreams());
          },
          color: BloodAppTheme.primary,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return ModernRequestCard(
                request: request,
                isRecipientView: false,
                onViewDetails: () => _showRequestDetails(request),
                onComplete:
                    request.isAccepted ? () => _completeRequest(request) : null,
                onChat: request.isAccepted ? () => _openChat(request) : null,
                showActions: request.isAccepted,
                showTimer: false,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStatsHeader(List<BloodRequest> requests) {
    final total = requests.length;
    final urgent = requests.where((r) => r.isUrgent).length;
    final critical = requests.where((r) => r.isCritical).length;
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
              const Icon(
                Icons.notifications_active,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Live Requests',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$total total',
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
              _buildStatBadge('Urgent', urgent, BloodAppTheme.warning),
              const SizedBox(width: 12),
              _buildStatBadge('Critical', critical, BloodAppTheme.error),
              const SizedBox(width: 12),
              _buildStatBadge('Expiring', expiring, Colors.orange),
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

  Widget _buildFilterChips() {
    final filters = ['all', 'urgent', 'expiring'];
    final filterLabels = {
      'all': 'All',
      'urgent': 'Urgent',
      'expiring': 'Expiring Soon',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children:
              filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      filterLabels[filter]!,
                      style: TextStyle(
                        color:
                            isSelected
                                ? Colors.white
                                : BloodAppTheme.textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color:
                            isSelected
                                ? BloodAppTheme.primary
                                : Colors.grey.shade300,
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
            Text(
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
              onPressed: () => setState(() => _initializeStreams()),
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
    bool showRefresh = false,
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
              style: TextStyle(
                color: BloodAppTheme.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (showRefresh) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => setState(() => _initializeStreams()),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<BloodRequest> _filterRequests(List<BloodRequest> requests) {
    switch (_selectedFilter) {
      case 'urgent':
        return requests.where((r) => r.isUrgent).toList();
      case 'expiring':
        return requests
            .where((r) => r.isAboutToExpire || r.isCritical)
            .toList();
      default:
        return requests;
    }
  }

  Future<void> _declineRequest(BloodRequest request) async {
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
                color: BloodAppTheme.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.do_not_disturb,
                color: BloodAppTheme.error,
              ),
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
            Text('Location: ${request.city}'),
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
                      'This request will be hidden from your list.',
                      style: TextStyle(
                        fontSize: 12,
                        color: BloodAppTheme.warning,
                      ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: BloodAppTheme.error,
            ),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final currentUserId = _auth.currentUser!.uid;

        // Remove donor from potential donors list
        await _donorMatchingService.removeDonorFromPotentialDonors(
          request.id,
          currentUserId,
        );

        if (mounted) {
          AppSnackbar.showInfo(
            context,
            'Request declined',
            subtitle: 'You won\'t see this request anymore',
          );
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.showError(context, 'Failed to decline request', subtitle: e.toString());
        }
      }
    }
  }

  Future<void> _acceptRequest(BloodRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
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
                  child: const Icon(
                    Icons.volunteer_activism,
                    color: BloodAppTheme.success,
                  ),
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
                Text('Location: ${request.city}'),
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
                          'This request will be assigned to you and a chat will be started with the recipient.',
                          style: TextStyle(
                            fontSize: 12,
                            color: BloodAppTheme.info,
                          ),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: BloodAppTheme.success,
                ),
                child: const Text('Accept', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        final currentUserId = _auth.currentUser!.uid;
        final userDoc =
            await _firestore.collection('users').doc(currentUserId).get();
        final donorName = userDoc.data()?['fullName'] ?? 'Anonymous Donor';

        // 🔧 FIXED: Use the repository method which handles everything:
        // - Updates status to 'accepted'
        // - Sets acceptedByType to 'donor'
        // - Clears potentialDonors array (removes from other donors)
        // - Initializes chat thread
        // - Cancels expiration timer
        await BloodRequestRepository().acceptRequestByDonor(
          request.id,
          currentUserId,
          donorName,
        );

        if (mounted) {
          AppSnackbar.showSuccess(
            context,
            'Request accepted successfully! 🎉',
            subtitle: 'You can now chat with the recipient to coordinate',
          );
          
          // Navigate to chat screen after accepting
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
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
      } catch (e) {
        if (mounted) {
          AppSnackbar.showError(context, 'Failed to accept request', subtitle: e.toString());
        }
      }
    }
  }

  Future<void> _completeRequest(BloodRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BloodAppTheme.radiusLg),
            ),
            title: const Text('Complete Donation?'),
            content: const Text(
              'Confirm that you have completed the blood donation.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not Yet'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
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
            'Donation completed! 🎉',
            subtitle: 'Thank you for saving a life!',
          );
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.showError(context, 'Failed to complete donation', subtitle: e.toString());
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    request.bloodType,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: BloodAppTheme.getBloodTypeColor(request.bloodType),
                    ),
                  ),
                ),
                const Spacer(),
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
                    'Requester',
                    request.requesterName,
                    Icons.person,
                  ),
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
                  _buildDetailRow(
                    'Address',
                    request.address,
                    Icons.location_on,
                  ),
                  if (request.hospital != null)
                    _buildDetailRow(
                      'Hospital',
                      request.hospital!,
                      Icons.local_hospital,
                    ),
                  if (request.phone != null)
                    _buildDetailRow('Phone', request.phone!, Icons.phone),
                  if (request.notes != null && request.notes!.isNotEmpty)
                    _buildDetailRow('Notes', request.notes!, Icons.note),
                  _buildDetailRow('Status', request.statusText, Icons.info),
                  _buildDetailRow(
                    'Created',
                    _formatDateTime(request.createdAt),
                    Icons.access_time,
                  ),
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
                  style: TextStyle(
                    fontSize: 12,
                    color: BloodAppTheme.textSecondary,
                  ),
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
