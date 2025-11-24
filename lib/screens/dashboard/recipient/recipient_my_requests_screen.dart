import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RecipientMyRequestsScreen extends StatelessWidget {
  const RecipientMyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Requests')),
        body: const Center(child: Text('Not logged in')),
      );
    }

    final q = FirebaseFirestore.instance
        .collection('blood_requests')
        .where('requesterId', isEqualTo: uid)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('My Requests')),
      body: StreamBuilder<QuerySnapshot>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text('No requests yet.'));
          }
          final docs = snap.data!.docs;
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final bloodType = (d['bloodType'] ?? '') as String;
              final city = (d['city'] ?? '') as String;
              final urgency = (d['urgency'] ?? 'normal') as String;
              final status = (d['status'] ?? 'active') as String;
              final ts = d['createdAt'];
              final createdAt = (ts is Timestamp) ? ts.toDate() : null;

              return ListTile(
                title: Text('$bloodType • $city • ${urgency.toUpperCase()}'),
                subtitle: Text('Status: ${status.toUpperCase()}'
                    '${createdAt != null ? '\nPosted: $createdAt' : ''}'),
                isThreeLine: createdAt != null,
                trailing: _statusChip(status),
                onTap: () {
                  // Future: open details / chat if accepted
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _statusChip(String status) {
    Color c;
    switch (status) {
      case 'accepted':
        c = Colors.orange;
        break;
      case 'completed':
        c = Colors.green;
        break;
      case 'cancelled':
        c = Colors.grey;
        break;
      default:
        c = Colors.blue;
    }
    return Chip(label: Text(status), backgroundColor: c.withOpacity(0.15));
  }
}
