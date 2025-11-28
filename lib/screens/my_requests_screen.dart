import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/blood_request_model.dart';
import '../providers/request_provider.dart';
import '../widgets/request_card.dart';
import '../widgets/countdown_timer.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({Key? key}) : super(key: key);

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  final _auth = FirebaseAuth.instance;

  String _selectedFilter = 'all';
  final List<String> _statusFilters = ['all', 'active', 'accepted', 'completed', 'expired', 'cancelled'];

  @override
  void initState() {
    super.initState();
    // Initialize the provider when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<RequestProvider>(context, listen: false);
      provider.initialize();
    });
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
      ),
      body: Consumer<RequestProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return _buildLoadingState();
          }

          if (provider.errorMessage != null) {
            return _buildErrorState(provider);
          }

          final filteredRequests = _filterRequests(provider.requests);

          return Column(
            children: [
              // Status Filter Chips
              _buildStatusFilterChips(),

              // Statistics Overview
              _buildStatisticsOverview(provider),

              // Requests List
              if (filteredRequests.isEmpty)
                _buildEmptyState()
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshData,
                    child: ListView.builder(
                      itemCount: filteredRequests.length,
                      padding: const EdgeInsets.all(8),
                      itemBuilder: (context, index) {
                        final request = filteredRequests[index];
                        return RequestCard(
                          request: request,
                          isRecipientView: true,
                          onViewDetails: () => _viewRequestDetails(request, context),
                          onCancel: () => _cancelRequest(request, context, provider),
                          showActions: request.isActive || request.isAccepted,
                        );
                      },
                    ),
                  ),
                ),
            ],
          );
        },
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

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF67D5B5)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Loading your requests...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
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

  Widget _buildStatisticsOverview(RequestProvider provider) {
    final activeCount = provider.activeRequests.length;
    final acceptedCount = provider.acceptedRequestsList.length;
    final completedCount = provider.completedRequests.length;
    final expiredCount = provider.expiredRequests.length;
    final urgentCount = provider.urgentRequestsCount;
    final expiringSoonCount = provider.expiringSoonCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Active', activeCount, Colors.orange),
              _buildStatItem('Accepted', acceptedCount, Colors.green),
              _buildStatItem('Completed', completedCount, Colors.blue),
              _buildStatItem('Expired', expiredCount, Colors.red),
            ],
          ),

          // Warning indicators
          if (urgentCount > 0 || expiringSoonCount > 0) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (urgentCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning, size: 14, color: Colors.red),
                        const SizedBox(width: 4),
                        Text(
                          '$urgentCount urgent',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (expiringSoonCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          '$expiringSoonCount expiring soon',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
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

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bloodtype_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _selectedFilter == 'all'
                  ? 'No blood requests yet'
                  : 'No ${_getStatusLabel(_selectedFilter).toLowerCase()} requests',
              style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            if (_selectedFilter == 'all')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Create your first blood request to find donors in your area',
                  style: TextStyle(color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 24),
            if (_selectedFilter == 'all')
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/recipient/request');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF67D5B5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Create First Request'),
              ),
          ],
        ),
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
              color: Color(0xFF67D5B5),
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
                  'Request Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
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
                          style: TextStyle(
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