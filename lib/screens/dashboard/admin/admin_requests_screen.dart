import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminRequestsScreen extends StatelessWidget {
  const AdminRequestsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blood Requests Monitor'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('blood_requests')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No blood requests found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final request = snapshot.data!.docs[index];
              final data = request.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(
                    Icons.bloodtype,
                    color: _getStatusColor(data['status'] ?? 'active'),
                  ),
                  title: Text('Blood Type: ${data['bloodType'] ?? 'Unknown'}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status: ${data['status'] ?? 'active'}'),
                      Text('Urgency: ${data['urgency'] ?? 'normal'}'),
                      if (data['createdAt'] != null)
                        Text('Created: ${_formatTimestamp(data['createdAt'])}'),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.info),
                    onPressed: () {
                      // Show request details
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed': return Colors.green;
      case 'active': return Colors.blue;
      case 'accepted': return Colors.orange;
      default: return Colors.grey;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate().toString().split(' ')[0];
    }
    return 'Unknown';
  }
}