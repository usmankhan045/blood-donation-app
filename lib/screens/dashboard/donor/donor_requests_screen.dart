// lib/screens/dashboard/donor/donor_requests_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DonorRequestsScreen extends StatefulWidget {
  const DonorRequestsScreen({super.key});

  @override
  State<DonorRequestsScreen> createState() => _DonorRequestsScreenState();
}

class _DonorRequestsScreenState extends State<DonorRequestsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> _loadDonorProfile() async {
    final uid = _auth.currentUser!.uid;
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _requestsStream(String bloodType) {
    // MVP: city-locked + bloodType match + active
    return _firestore
        .collection('blood_requests')
        .where('city', isEqualTo: 'Abbottabad')
        .where('status', isEqualTo: 'active')
        .where('bloodType', isEqualTo: bloodType)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _acceptRequest(String requestId) async {
    try {
      final uid = _auth.currentUser!.uid;
      await _firestore.runTransaction((tx) async {
        final ref = _firestore.collection('blood_requests').doc(requestId);
        final snap = await tx.get(ref);
        if (!snap.exists) {
          throw Exception('Request not found');
        }
        final status = snap.data()!['status'] as String? ?? 'active';
        if (status != 'active') {
          throw Exception('Request is not active');
        }
        tx.update(ref, {
          'status': 'accepted',
          'acceptedBy': uid,
          'acceptedAt': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request accepted.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept: $e')),
        );
      }
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
        final role = (donor['role'] ?? '').toString().toLowerCase();
        final bloodType = (donor['bloodType'] ?? '').toString().toUpperCase();

        if (role != 'donor' || bloodType.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Requests')),
            body: const Center(
              child: Text('This view is only for donors with a set blood type.'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Abbottabad Requests')),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _requestsStream(bloodType),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('No active requests right now.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final data = docs[i].data();
                  final id = docs[i].id;
                  final bloodType = (data['bloodType'] ?? '').toString();
                  final urgency = (data['urgency'] ?? '').toString();
                  final address = (data['address'] ?? 'Abbottabad').toString();
                  final requester = (data['requesterName'] ?? 'Recipient').toString();
                  final createdAt = data['createdAt'];
                  final neededBy = data['neededBy'];
                  final status = (data['status'] ?? '').toString();

                  return Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Blood: $bloodType',
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: urgency.toLowerCase() == 'urgent'
                                      ? Colors.red.withOpacity(0.12)
                                      : Colors.orange.withOpacity(0.12),
                                ),
                                child: Text(
                                  urgency.toUpperCase(),
                                  style: TextStyle(
                                    color: urgency.toLowerCase() == 'urgent'
                                        ? Colors.red
                                        : Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Requester: $requester'),
                          const SizedBox(height: 4),
                          Text('Address: $address'),
                          if (createdAt != null) ...[
                            const SizedBox(height: 4),
                            Text('Posted: ${_friendlyTimestamp(createdAt)}'),
                          ],
                          if (neededBy != null) ...[
                            const SizedBox(height: 4),
                            Text('Needed by: ${_friendlyTimestamp(neededBy)}'),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: status == 'active'
                                    ? () => _acceptRequest(id)
                                    : null,
                                icon: const Icon(Icons.check),
                                label: const Text('Accept'),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () {
                                  // Optional: later we can open external maps (url_launcher).
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Map deep-link coming soon.'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.map_outlined),
                                label: const Text('View Map'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  String _friendlyTimestamp(dynamic ts) {
    try {
      final dt = (ts as Timestamp).toDate();
      return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} '
          '${_two(dt.hour)}:${_two(dt.minute)}';
    } catch (_) {
      return '-';
    }
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}
