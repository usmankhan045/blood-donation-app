import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/blood_request_model.dart';
import '../../../providers/request_provider.dart';
import '../../../widgets/request_card.dart';
import '../../../widgets/countdown_timer.dart';
import '../../../services/donor_matching_service.dart';

class DonorRequestsScreen extends StatefulWidget {
  const DonorRequestsScreen({super.key});

  @override
  State<DonorRequestsScreen> createState() => _DonorRequestsScreenState();
}

class _DonorRequestsScreenState extends State<DonorRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'all';
  final List<String> _statusFilters = ['all', 'active', 'accepted', 'completed'];

  final DonorMatchingService _donorMatchingService = DonorMatchingService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream for incoming requests where donor is in potentialDonors
  Stream<List<BloodRequest>>? _incomingRequestsStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeStreams();

    // Initialize the provider when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<RequestProvider>(context, listen: false);
      provider.initialize();
    });
  }

  void _initializeStreams() {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      // Stream for requests where this donor is in potentialDonors array
      _incomingRequestsStream = _firestore
          .collection('blood_requests')
          .where('potentialDonors', arrayContains: userId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
          .map((doc) => BloodRequest.fromDoc(doc)) // ✅ FIXED: Changed fromFirestore to fromDoc
          .toList());

      print('🎯 Started listening for incoming requests for donor: $userId');
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
      appBar: AppBar(
        title: const Text('Blood Requests'),
        backgroundColor: Color(0xFF67D5B5),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(
              icon: Icon(Icons.notifications_active),
              text: 'Available Requests',
            ),
            Tab(
              icon: Icon(Icons.check_circle),
              text: 'My Accepted',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Available Requests Tab - NOW USING REAL-TIME STREAM
          _buildAvailableRequestsStream(),

          // Accepted Requests Tab
          _buildAcceptedRequestsTab(),
        ],
      ),
    );
  }

  // UPDATED: Use real-time stream for available requests
  Widget _buildAvailableRequestsStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null || _incomingRequestsStream == null) {
      return _buildErrorState('User not logged in');
    }

    return StreamBuilder<List<BloodRequest>>(
      stream: _incomingRequestsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState('Loading available requests...');
        }

        if (snapshot.hasError) {
          return _buildErrorState('Error loading requests: ${snapshot.error}');
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            'No Available Requests',
            'When new blood requests match your blood type and location,\nthey will appear here automatically.',
            true,
          );
        }

        final availableRequests = snapshot.data!;
        final filteredRequests = _filterRequests(availableRequests, isAvailable: true);

        print('📬 Displaying ${filteredRequests.length} available requests');

        return _buildRequestsList(
          requests: filteredRequests,
          emptyMessage: 'No Available Requests',
          emptyDescription: 'When new blood requests match your blood type,\nthey will appear here with countdown timers.',
          showStatistics: true,
          isDonorView: true,
          isAvailableTab: true,
        );
      },
    );
  }

  Widget _buildAcceptedRequestsTab() {
    return Consumer<RequestProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return _buildLoadingState('Loading your accepted requests...');
        }

        final acceptedRequests = provider.acceptedRequests;
        final filteredAccepted = _filterRequests(acceptedRequests, isAvailable: false);

        return _buildRequestsList(
          requests: filteredAccepted,
          emptyMessage: 'No Accepted Requests',
          emptyDescription: 'Requests you accept will appear here.\nComplete them after donation.',
          showStatistics: false,
          provider: provider,
          isDonorView: true,
          isAvailableTab: false,
        );
      },
    );
  }

  Widget _buildRequestsList({
    required List<BloodRequest> requests,
    required String emptyMessage,
    required String emptyDescription,
    required bool showStatistics,
    RequestProvider? provider,
    required bool isDonorView,
    required bool isAvailableTab,
  }) {
    if (requests.isEmpty) {
      return _buildEmptyState(emptyMessage, emptyDescription, isAvailableTab);
    }

    return Column(
      children: [
        // Statistics Overview for available requests
        if (showStatistics) _buildStatisticsOverview(requests, isAvailableTab),

        // Status Filter Chips
        _buildStatusFilterChips(isAvailableTab),

        // Requests List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshData,
            child: ListView.builder(
              itemCount: requests.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final request = requests[index];
                return RequestCard(
                  request: request,
                  isRecipientView: false,
                  onAccept: () => _acceptRequest(request, context),
                  onViewDetails: () => _viewRequestDetails(request, context),
                  onCancel: isAvailableTab ? null : () => _completeRequest(request, context, provider),
                  showActions: true,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF67D5B5)),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String errorMessage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error loading requests',
            style: TextStyle(fontSize: 18, color: Colors.grey[800]),
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage,
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF67D5B5),
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  // UPDATED: Statistics based on actual stream data
  Widget _buildStatisticsOverview(List<BloodRequest> requests, bool isAvailableTab) {
    if (isAvailableTab) {
      final availableCount = requests.length;
      final urgentCount = requests.where((r) => r.isUrgent).length;
      final expiringSoonCount = requests.where((r) => r.isAboutToExpire).length;
      final criticalCount = requests.where((r) => r.isCritical).length;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active, color: Color(0xFF67D5B5), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Live Requests',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFF67D5B5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$availableCount request${availableCount != 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Color(0xFF67D5B5),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Quick stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Total', availableCount, Colors.blue, Icons.bloodtype),
                _buildStatItem('Urgent', urgentCount, Colors.orange, Icons.warning),
                _buildStatItem('Critical', criticalCount, Colors.red, Icons.emergency),
                _buildStatItem('Expiring', expiringSoonCount, Colors.orange, Icons.timer),
              ],
            ),
          ],
        ),
      );
    } else {
      final acceptedCount = requests.length;
      final completedCount = requests.where((r) => r.isCompleted).length;
      final pendingCount = acceptedCount - completedCount;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Accepted Requests',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Accepted', acceptedCount, Colors.green, Icons.check_circle),
                _buildStatItem('Pending', pendingCount, Colors.orange, Icons.pending),
                _buildStatItem('Completed', completedCount, Colors.blue, Icons.verified),
              ],
            ),
          ],
        ),
      );
    }
  }

  Widget _buildStatItem(String label, int count, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusFilterChips(bool isAvailableTab) {
    final filters = isAvailableTab
        ? ['all', 'active', 'urgent', 'expiring']
        : ['all', 'accepted', 'completed'];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: filters.map((status) {
          return ChoiceChip(
            label: Text(
              _getStatusLabel(status, isAvailableTab),
              style: TextStyle(
                color: _selectedFilter == status ? Colors.white : Colors.black87,
                fontSize: 12,
              ),
            ),
            selected: _selectedFilter == status,
            onSelected: (selected) {
              setState(() => _selectedFilter = status);
            },
            selectedColor: Color(0xFF67D5B5),
            backgroundColor: Colors.grey[200],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(String message, String description, bool isAvailableTab) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isAvailableTab ? Icons.bloodtype_outlined : Icons.check_circle_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              description,
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ),
          if (isAvailableTab) ...[
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _refreshData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF67D5B5),
                foregroundColor: Colors.white,
              ),
              child: const Text('Check for New Requests'),
            ),
          ],
        ],
      ),
    );
  }

  List<BloodRequest> _filterRequests(List<BloodRequest> requests, {required bool isAvailable}) {
    if (_selectedFilter == 'all') {
      return requests;
    }

    return requests.where((request) {
      if (isAvailable) {
        switch (_selectedFilter) {
          case 'active':
            return request.isActive;
          case 'urgent':
            return request.isUrgent;
          case 'expiring':
            return request.isAboutToExpire || request.isCritical;
          default:
            return true;
        }
      } else {
        switch (_selectedFilter) {
          case 'accepted':
            return request.isAccepted;
          case 'completed':
            return request.isCompleted;
          default:
            return true;
        }
      }
    }).toList();
  }

  String _getStatusLabel(String status, bool isAvailableTab) {
    if (isAvailableTab) {
      switch (status) {
        case 'all': return 'All';
        case 'active': return 'Active';
        case 'urgent': return 'Urgent';
        case 'expiring': return 'Expiring Soon';
        default: return status;
      }
    } else {
      switch (status) {
        case 'all': return 'All';
        case 'accepted': return 'Accepted';
        case 'completed': return 'Completed';
        default: return status;
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _initializeStreams();
    });

    final provider = Provider.of<RequestProvider>(context, listen: false);
    await provider.refreshAllData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Refreshing requests...'),
        backgroundColor: Color(0xFF67D5B5),
      ),
    );
  }

  // UPDATED: Accept request with proper donor matching service integration
  Future<void> _acceptRequest(BloodRequest request, BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Request?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to accept this blood request?'),
            const SizedBox(height: 8),
            Text(
              'Blood Type: ${request.bloodType}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Location: ${request.city}'),
            Text('Units: ${request.units}'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Note: This request will be removed from other donors once you accept it.',
                style: TextStyle(fontSize: 12, color: Colors.orange),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Accept Request'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final currentUserId = _auth.currentUser!.uid;

        // Get donor name from user profile
        final userDoc = await _firestore.collection('users').doc(currentUserId).get();
        final userData = userDoc.data();
        final donorName = userData?['fullName'] ?? 'Anonymous Donor';

        // Remove this donor from potential donors of other requests
        await _donorMatchingService.removeDonorFromPotentialDonors(request.id, currentUserId);

        // Update request status to accepted
        await _firestore.collection('blood_requests').doc(request.id).update({
          'status': 'accepted',
          'acceptedBy': currentUserId,
          'acceptedAt': FieldValue.serverTimestamp(),
          'acceptedDonorName': donorName,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Refresh the data
        _refreshData();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request accepted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _completeRequest(BloodRequest request, BuildContext context, RequestProvider? provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Donation?'),
        content: const Text('Confirm that you have completed the blood donation for this request.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Yes, Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true && provider != null) {
      try {
        await provider.completeRequest(request.id);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Donation marked as completed!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewRequestDetails(BloodRequest request, BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildRequestDetailsSheet(request, context),
    );
  }

  Widget _buildRequestDetailsSheet(BloodRequest request, BuildContext context) {
    final isAccepted = request.isAccepted || request.isCompleted;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isAccepted ? Colors.green : Color(0xFF67D5B5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  isAccepted ? 'Accepted Request' : 'Request Details',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status and Blood Type
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _getBloodTypeColor(request.bloodType),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          request.bloodType,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: request.statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: request.statusColor),
                        ),
                        child: Text(
                          request.statusText.toUpperCase(),
                          style: TextStyle(
                            color: request.statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Countdown Timer for active requests
                  if (request.isActive) ...[
                    Center(
                      child: CountdownTimer(
                        duration: request.timeRemaining ?? Duration.zero,
                        request: request,
                        size: 120,
                        onExpired: () {
                          Navigator.pop(context);
                          _refreshData();
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Request Details
                  _buildDetailSection('Requester Information', [
                    _buildDetailItem('Requester Name', request.requesterName),
                    _buildDetailItem('Contact Phone', request.phone ?? 'Not provided'),
                  ]),

                  _buildDetailSection('Request Information', [
                    _buildDetailItem('Units Required', '${request.units} unit(s)'),
                    _buildDetailItem('Urgency', request.urgency.toUpperCase(), request.urgencyColor),
                    _buildDetailItem('Search Radius', '${request.searchRadius} km'),
                  ]),

                  _buildDetailSection('Location Information', [
                    _buildDetailItem('City', request.city),
                    _buildDetailItem('Address', request.address),
                    if (request.hospital != null) _buildDetailItem('Hospital', request.hospital!),
                  ]),

                  if (request.notes != null && request.notes!.isNotEmpty)
                    _buildDetailSection('Additional Notes', [
                      _buildDetailItem('Notes', request.notes!),
                    ]),

                  _buildDetailSection('Timeline', [
                    _buildDetailItem('Created', _formatDate(request.createdAt ?? DateTime.now())),
                    if (request.neededBy != null) _buildDetailItem('Needed By', _formatDate(request.neededBy!)),
                    if (request.acceptedAt != null) _buildDetailItem('Accepted At', _formatDate(request.acceptedAt!)),
                  ]),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.black87,
                fontWeight: valueColor != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getBloodTypeColor(String bloodType) {
    switch (bloodType) {
      case 'A+': return Colors.red.shade600;
      case 'A-': return Colors.red.shade800;
      case 'B+': return Colors.blue.shade600;
      case 'B-': return Colors.blue.shade800;
      case 'AB+': return Colors.purple.shade600;
      case 'AB-': return Colors.purple.shade800;
      case 'O+': return Colors.green.shade600;
      case 'O-': return Colors.green.shade800;
      default: return Colors.grey.shade600;
    }
  }

  String _formatDate(DateTime date) {
    return '${_getWeekday(date.weekday)} ${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getWeekday(int weekday) {
    switch (weekday) {
      case 1: return 'Mon';
      case 2: return 'Tue';
      case 3: return 'Wed';
      case 4: return 'Thu';
      case 5: return 'Fri';
      case 6: return 'Sat';
      case 7: return 'Sun';
      default: return '';
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Requests'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: _statusFilters.map((status) {
              return ListTile(
                leading: Radio<String>(
                  value: status,
                  groupValue: _selectedFilter,
                  onChanged: (value) {
                    setState(() => _selectedFilter = value!);
                    Navigator.pop(context);
                  },
                ),
                title: Text(_getStatusLabel(status, _tabController.index == 0)),
                onTap: () {
                  setState(() => _selectedFilter = status);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}