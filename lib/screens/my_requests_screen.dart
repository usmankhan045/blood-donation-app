import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

// Move the class outside the State class
class SimpleBloodRequest {
  final String id;
  final String bloodType;
  final int units;
  final String status;
  final String city;
  final String address;
  final String? hospital;
  final String? phone;
  final String? notes;
  final String? acceptedBy;
  final DateTime? createdAt;
  final DateTime? neededBy;
  final String urgency;
  final int searchRadius;

  SimpleBloodRequest({
    required this.id,
    required this.bloodType,
    required this.units,
    required this.status,
    required this.city,
    required this.address,
    this.hospital,
    this.phone,
    this.notes,
    this.acceptedBy,
    this.createdAt,
    this.neededBy,
    required this.urgency,
    required this.searchRadius,
  });

  // Factory method to create from Firestore document
  factory SimpleBloodRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    return SimpleBloodRequest(
      id: doc.id,
      bloodType: data['bloodType'] ?? 'Unknown',
      units: (data['units'] as num?)?.toInt() ?? 1,
      status: data['status'] ?? 'active',
      city: data['city'] ?? '',
      address: data['address'] ?? '',
      hospital: data['hospital'],
      phone: data['phone'],
      notes: data['notes'],
      acceptedBy: data['acceptedBy'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      neededBy: (data['neededBy'] as Timestamp?)?.toDate(),
      urgency: data['urgency'] ?? 'normal',
      searchRadius: (data['searchRadius'] as num?)?.toInt() ?? 10,
    );
  }
}

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({Key? key}) : super(key: key);

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  String _selectedFilter = 'all';
  final List<String> _statusFilters = ['all', 'active', 'accepted', 'completed', 'cancelled'];

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
        ],
      ),
      body: Column(
        children: [
          // Status Filter Chips
          _buildStatusFilterChips(),

          // Requests List
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _getMyRequestsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final requests = snapshot.data!.docs;

                if (requests.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  itemCount: requests.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final doc = requests[index];
                    final request = SimpleBloodRequest.fromDoc(doc);
                    return _buildRequestCard(request, context);
                  },
                );
              },
            ),
          ),
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

  Widget _buildStatusFilterChips() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        children: _statusFilters.map((status) {
          return ChoiceChip(
            label: Text(
              _getStatusLabel(status),
              style: TextStyle(
                color: _selectedFilter == status ? Colors.white : Colors.black87,
              ),
            ),
            selected: _selectedFilter == status,
            onSelected: (selected) {
              setState(() => _selectedFilter = status);
            },
            selectedColor: Color(0xFF67D5B5),
          );
        }).toList(),
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'all': return 'All';
      case 'active': return 'Active';
      case 'accepted': return 'Accepted';
      case 'completed': return 'Completed';
      case 'cancelled': return 'Cancelled';
      default: return status;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getMyRequestsStream() {
    final user = _auth.currentUser!;
    Query<Map<String, dynamic>> query = _fs.collection('requests')
        .where('requesterId', isEqualTo: user.uid);

    if (_selectedFilter != 'all') {
      query = query.where('status', isEqualTo: _selectedFilter);
    }

    return query.orderBy('createdAt', descending: true).snapshots();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bloodtype_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == 'all'
                ? 'No blood requests yet'
                : 'No ${_selectedFilter} requests',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          if (_selectedFilter == 'all')
            Text(
              'Tap the + button to create your first request',
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(SimpleBloodRequest request, BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status and blood type
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  request.bloodType,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(request.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getStatusColor(request.status)),
                  ),
                  child: Text(
                    request.status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(request.status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Request details
            _buildDetailRow(Icons.bloodtype, '${request.units} unit(s)'),
            _buildDetailRow(Icons.location_on, '${request.city} • ${request.address}'),
            _buildDetailRow(Icons.calendar_today,
                'Created: ${_formatDate(request.createdAt ?? DateTime.now())}'),

            if (request.acceptedBy != null && request.status == 'accepted') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Accepted by a donor',
                      style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],

            if (request.status == 'completed') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified, color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Donation completed successfully',
                      style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Action buttons based on status
            _buildActionButtons(request, context),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: Colors.grey[700]))),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active': return Colors.orange;
      case 'accepted': return Colors.green;
      case 'completed': return Colors.blue;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildActionButtons(SimpleBloodRequest request, BuildContext context) {
    switch (request.status) {
      case 'active':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _viewRequestDetails(request, context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Color(0xFF67D5B5),
                  side: BorderSide(color: Color(0xFF67D5B5)),
                ),
                child: const Text('View Details'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _cancelRequest(request, context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Cancel'),
              ),
            ),
          ],
        );

      case 'accepted':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _viewRequestDetails(request, context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Color(0xFF67D5B5),
                  side: BorderSide(color: Color(0xFF67D5B5)),
                ),
                child: const Text('View Details'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _markAsCompleted(request, context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Mark Completed'),
              ),
            ),
          ],
        );

      default:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _viewRequestDetails(request, context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Color(0xFF67D5B5),
              side: BorderSide(color: Color(0xFF67D5B5)),
            ),
            child: const Text('View Details'),
          ),
        );
    }
  }

  void _viewRequestDetails(SimpleBloodRequest request, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Request Details - ${request.bloodType}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem('Status', request.status.toUpperCase(),
                  _getStatusColor(request.status)),
              _buildDetailItem('Blood Type', request.bloodType),
              _buildDetailItem('Units Required', '${request.units} unit(s)'),
              _buildDetailItem('Urgency', request.urgency.toUpperCase()),
              _buildDetailItem('City', request.city),
              _buildDetailItem('Address', request.address),
              if (request.hospital != null) _buildDetailItem('Hospital', request.hospital!),
              if (request.phone != null) _buildDetailItem('Contact Phone', request.phone!),
              if (request.notes != null) _buildDetailItem('Notes', request.notes!),
              if (request.neededBy != null) _buildDetailItem('Needed By', _formatDate(request.neededBy!)),
              _buildDetailItem('Search Radius', '${request.searchRadius} km'),
              _buildDetailItem('Created', _formatDate(request.createdAt ?? DateTime.now())),
              if (request.acceptedBy != null) _buildDetailItem('Accepted By', 'User ID: ${request.acceptedBy}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelRequest(SimpleBloodRequest request, BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Request?'),
        content: const Text('Are you sure you want to cancel this blood request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
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
        // Direct Firestore call since provider might not exist
        await _fs.collection('requests').doc(request.id).update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });

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

  Future<void> _markAsCompleted(SimpleBloodRequest request, BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Completed?'),
        content: const Text('Confirm that the blood donation has been completed successfully.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Yes, Completed'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Direct Firestore call since provider might not exist
        await _fs.collection('requests').doc(request.id).update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request marked as completed'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing request: $e'),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
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
    );
  }
}