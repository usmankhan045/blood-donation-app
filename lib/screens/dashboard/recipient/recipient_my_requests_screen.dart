import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/blood_request_model.dart';
import '../../../providers/request_provider.dart';
import '../../../widgets/request_card.dart';
import '../../../widgets/countdown_timer.dart';

class RecipientMyRequestsScreen extends StatefulWidget {
  const RecipientMyRequestsScreen({super.key});

  @override
  State<RecipientMyRequestsScreen> createState() => _RecipientMyRequestsScreenState();
}

class _RecipientMyRequestsScreenState extends State<RecipientMyRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'all';
  final List<String> _statusFilters = ['all', 'active', 'accepted', 'completed', 'expired', 'cancelled'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Initialize the provider when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<RequestProvider>(context, listen: false);
      provider.initialize();
    });
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
        title: const Text('My Blood Requests'),
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
            Tab(text: 'Current Requests', icon: Icon(Icons.pending_actions)),
            Tab(text: 'Request History', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Current Requests Tab
          _buildCurrentRequestsTab(),

          // Request History Tab
          _buildRequestHistoryTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/recipient/request');
        },
        backgroundColor: Color(0xFF67D5B5),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildCurrentRequestsTab() {
    return Consumer<RequestProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return _buildLoadingState('Loading your requests...');
        }

        if (provider.errorMessage != null) {
          return _buildErrorState(provider);
        }

        final currentRequests = provider.requests.where((request) =>
        request.isActive || request.isAccepted
        ).toList();

        final filteredRequests = _filterRequests(currentRequests);

        return _buildRequestsList(
          requests: filteredRequests,
          emptyMessage: 'No current blood requests',
          emptyDescription: 'Create a new request to find donors in your area',
          showStatistics: true,
          provider: provider,
        );
      },
    );
  }

  Widget _buildRequestHistoryTab() {
    return Consumer<RequestProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return _buildLoadingState('Loading your history...');
        }

        final historyRequests = provider.requests.where((request) =>
        request.isCompleted || request.isExpiredStatus || request.isCancelled
        ).toList();

        final filteredHistory = _filterRequests(historyRequests);

        return _buildRequestsList(
          requests: filteredHistory,
          emptyMessage: 'No request history',
          emptyDescription: 'Your completed, expired, and cancelled requests will appear here',
          showStatistics: false,
          provider: provider,
          isHistoryView: true,
        );
      },
    );
  }

  Widget _buildRequestsList({
    required List<BloodRequest> requests,
    required String emptyMessage,
    required String emptyDescription,
    required bool showStatistics,
    required RequestProvider provider,
    bool isHistoryView = false,
  }) {
    if (requests.isEmpty) {
      return _buildEmptyState(emptyMessage, emptyDescription, isHistoryView);
    }

    return Column(
      children: [
        // Statistics Overview for current requests
        if (showStatistics) _buildStatisticsOverview(provider),

        // Status Filter Chips
        _buildStatusFilterChips(),

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
                  isRecipientView: true,
                  onViewDetails: () => _viewRequestDetails(request, context),
                  onCancel: isHistoryView ? null : () => _cancelRequest(request, context, provider),
                  showActions: !isHistoryView && (request.isActive || request.isAccepted),
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

  Widget _buildErrorState(RequestProvider provider) {
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
            provider.errorMessage!,
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

  Widget _buildStatisticsOverview(RequestProvider provider) {
    final activeCount = provider.activeRequests.length;
    final acceptedCount = provider.acceptedRequestsList.length;
    final urgentCount = provider.urgentRequestsCount;
    final expiringSoonCount = provider.expiringSoonCount;

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
            'Current Requests Overview',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          // Quick stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Active', activeCount, Colors.orange, Icons.pending),
              _buildStatItem('Accepted', acceptedCount, Colors.green, Icons.check_circle),
              _buildStatItem('Urgent', urgentCount, Colors.red, Icons.warning),
              _buildStatItem('Expiring', expiringSoonCount, Colors.orange, Icons.timer),
            ],
          ),
        ],
      ),
    );
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

  Widget _buildStatusFilterChips() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _statusFilters.map((status) {
          return ChoiceChip(
            label: Text(
              _getStatusLabel(status),
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

  Widget _buildEmptyState(String message, String description, bool isHistoryView) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isHistoryView ? Icons.history_outlined : Icons.bloodtype_outlined,
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
          const SizedBox(height: 24),
          if (!isHistoryView)
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/recipient/request');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF67D5B5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Create New Request'),
            ),
        ],
      ),
    );
  }

  List<BloodRequest> _filterRequests(List<BloodRequest> requests) {
    if (_selectedFilter == 'all') {
      return requests;
    }

    return requests.where((request) {
      switch (_selectedFilter) {
        case 'active':
          return request.isActive;
        case 'accepted':
          return request.isAccepted;
        case 'completed':
          return request.isCompleted;
        case 'expired':
          return request.isExpiredStatus;
        case 'cancelled':
          return request.isCancelled;
        default:
          return true;
      }
    }).toList();
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'all': return 'All';
      case 'active': return 'Active';
      case 'accepted': return 'Accepted';
      case 'completed': return 'Completed';
      case 'expired': return 'Expired';
      case 'cancelled': return 'Cancelled';
      default: return status;
    }
  }

  Future<void> _refreshData() async {
    final provider = Provider.of<RequestProvider>(context, listen: false);
    await provider.refreshAllData();
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
    final isHistory = request.isCompleted || request.isExpiredStatus || request.isCancelled;

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
              color: isHistory ? Colors.grey[600] : Color(0xFF67D5B5),
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
                  isHistory ? 'Request History' : 'Request Details',
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
                          request.historyStatus.toUpperCase(),
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

                  // Historical status message
                  if (isHistory) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: request.statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: request.statusColor),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getHistoryStatusIcon(request),
                            color: request.statusColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getHistoryStatusMessage(request),
                              style: TextStyle(
                                color: request.statusColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Request Details
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
                    if (request.completedAt != null) _buildDetailItem('Completed At', _formatDate(request.completedAt!)),
                    if (request.expiredAt != null) _buildDetailItem('Expired At', _formatDate(request.expiredAt!)),
                    if (request.cancelledAt != null) _buildDetailItem('Cancelled At', _formatDate(request.cancelledAt!)),
                  ]),

                  if (request.acceptedByName != null)
                    _buildDetailSection('Accepted By', [
                      _buildDetailItem('Donor Name', request.acceptedByName!),
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

  IconData _getHistoryStatusIcon(BloodRequest request) {
    if (request.isCompleted) return Icons.verified;
    if (request.isExpiredStatus) return Icons.timer_off;
    if (request.isCancelled) return Icons.cancel;
    return Icons.info;
  }

  String _getHistoryStatusMessage(BloodRequest request) {
    if (request.isCompleted) return 'This donation was completed successfully. Thank you for saving a life!';
    if (request.isExpiredStatus) return 'This request expired after 1 hour without finding a donor. You can create a new request if needed.';
    if (request.isCancelled) return 'This request was cancelled. You can create a new request anytime.';
    return 'This request is currently active.';
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

  Future<void> _cancelRequest(BloodRequest request, BuildContext context, RequestProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Request?'),
        content: const Text('Are you sure you want to cancel this blood request? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Request'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await provider.cancelRequest(request.id);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                title: Text(_getStatusLabel(status)),
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