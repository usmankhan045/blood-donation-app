// lib/screens/dashboard/donor/donor_requests_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../services/donor_service.dart';
import '../../../services/notification_service.dart';
import '../../../models/blood_request_model.dart';

class DonorRequestsScreen extends StatefulWidget {
  const DonorRequestsScreen({super.key});

  @override
  State<DonorRequestsScreen> createState() => _DonorRequestsScreenState();
}

class _DonorRequestsScreenState extends State<DonorRequestsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final DonorService _donorService = DonorService();
  final NotificationService _notificationService = NotificationService();

  Future<Map<String, dynamic>?> _loadDonorProfile() async {
    final uid = _auth.currentUser!.uid;
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  // Get available requests for current donor using DonorService
  Stream<List<BloodRequest>> _getAvailableRequests(String bloodType) {
    return _donorService.getAvailableRequests();
  }

  // Get accepted requests for current donor
  Stream<List<BloodRequest>> _getAcceptedRequests() {
    return _donorService.getAcceptedRequests();
  }

  Future<void> _acceptRequest(String requestId, String donorName) async {
    try {
      await _donorService.acceptRequest(requestId, donorName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Request accepted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _completeRequest(String requestId) async {
    try {
      await _donorService.completeRequest(requestId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Donation marked as completed!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _declineRequest(String requestId) async {
    try {
      await _donorService.declineRequest(requestId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Request declined'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to decline request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Get urgency color
  Color _getUrgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'emergency':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'normal':
        return Colors.blue;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // Get urgency icon
  IconData _getUrgencyIcon(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'emergency':
        return Icons.emergency;
      case 'high':
        return Icons.warning_amber;
      case 'normal':
        return Icons.info;
      case 'low':
        return Icons.low_priority;
      default:
        return Icons.bloodtype;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadDonorProfile(),
      builder: (context, donorSnap) {
        if (donorSnap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final donor = donorSnap.data ?? {};
        final userType = (donor['userType'] ?? donor['role'] ?? '').toString().toLowerCase();
        final bloodType = (donor['bloodGroup'] ?? donor['bloodType'] ?? '').toString().toUpperCase();
        final donorName = (donor['fullName'] ?? 'Donor').toString();

        if (userType != 'donor' || bloodType.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Blood Requests')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bloodtype, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Donor Access Only',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This screen is only available for registered donors with a blood type set in their profile.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Blood Requests'),
              bottom: const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.notifications_active), text: 'Available'),
                  Tab(icon: Icon(Icons.check_circle), text: 'Accepted'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                // Available Requests Tab
                _buildAvailableRequestsTab(bloodType, donorName),
                // Accepted Requests Tab
                _buildAcceptedRequestsTab(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvailableRequestsTab(String bloodType, String donorName) {
    return StreamBuilder<List<BloodRequest>>(
      stream: _getAvailableRequests(bloodType),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bloodtype_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No Active Requests',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'When new blood requests match your blood type,\nthey will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final request = requests[index];
            return _buildRequestCard(request, donorName, false);
          },
        );
      },
    );
  }

  Widget _buildAcceptedRequestsTab() {
    return StreamBuilder<List<BloodRequest>>(
      stream: _getAcceptedRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No Accepted Requests',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Requests you accept will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final request = requests[index];
            return _buildRequestCard(request, '', true);
          },
        );
      },
    );
  }

  Widget _buildRequestCard(BloodRequest request, String donorName, bool isAccepted) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Blood Type and Urgency
            Row(
              children: [
                Icon(Icons.bloodtype, color: Colors.red, size: 24),
                const SizedBox(width: 8),
                Text(
                  request.bloodType,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const Spacer(),
                Chip(
                  backgroundColor: _getUrgencyColor(request.urgency).withOpacity(0.1),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getUrgencyIcon(request.urgency),
                        size: 16,
                        color: _getUrgencyColor(request.urgency),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        request.urgency.toUpperCase(),
                        style: TextStyle(
                          color: _getUrgencyColor(request.urgency),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Request Details
            _buildDetailRow(Icons.person, 'Requester:', request.requesterName),
            _buildDetailRow(Icons.location_on, 'Location:', request.address),
            _buildDetailRow(Icons.local_hospital, 'Hospital:', request.hospital ?? 'Not specified'),
            _buildDetailRow(Icons.bloodtype, 'Units Needed:', '${request.units} unit(s)'),

            if (request.notes?.isNotEmpty ?? false) ...[
              _buildDetailRow(Icons.notes, 'Notes:', request.notes!),
            ],

            if (request.neededBy != null) ...[
              _buildDetailRow(
                Icons.calendar_today,
                'Needed by:',
                '${request.neededBy!.day}/${request.neededBy!.month}/${request.neededBy!.year}',
              ),
            ],

            _buildDetailRow(
              Icons.access_time,
              'Posted:',
              _friendlyTimestamp(request.createdAt ?? DateTime.now()),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            if (!isAccepted)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _acceptRequest(request.id, donorName),
                      icon: const Icon(Icons.check_circle, size: 20),
                      label: const Text('Accept Request'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _declineRequest(request.id),
                      icon: const Icon(Icons.cancel, size: 20),
                      label: const Text('Decline'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _completeRequest(request.id),
                      icon: const Icon(Icons.done_all, size: 20),
                      label: const Text('Complete Donation'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                children: [
                  TextSpan(
                    text: '$label ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _friendlyTimestamp(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${date.day}/${date.month}/${date.year}';
  }
}