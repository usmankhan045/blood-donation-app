import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme.dart';
import '../../services/fcm_service.dart';
import 'chat_screen.dart';

/// 💬 CHAT LIST SCREEN
/// Shows all active chats for the current user
/// Works for all user types: Donor, Recipient, Blood Bank, Hospital
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    // Set up FCM callback for direct chat navigation
    FCMService.setChatNavigationCallback(_navigateToChat);
  }

  /// Navigate to a specific chat from FCM notification
  void _navigateToChat(
    String threadId,
    String title,
    String subtitle,
    String? otherUserId,
  ) {
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ChatScreen(
              threadId: threadId,
              title: title,
              subtitle: subtitle,
              otherUserName: title,
              otherUserId: otherUserId,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BloodAppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: BloodAppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildChatList(),
    );
  }

  Widget _buildChatList() {
    final userId = _currentUserId;
    if (userId == null) {
      return const Center(child: Text('Please login to view messages'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection('chat_threads')
              .where('participants', arrayContains: userId)
              .orderBy('updatedAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(BloodAppTheme.primary),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState();
        }

        final threads = snapshot.data?.docs ?? [];

        if (threads.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: threads.length,
          itemBuilder: (context, index) {
            final thread = threads[index];
            return _ChatTile(
              threadId: thread.id,
              threadData: thread.data() as Map<String, dynamic>,
              currentUserId: userId,
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    BloodAppTheme.primary.withOpacity(0.1),
                    BloodAppTheme.accent.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 64,
                color: BloodAppTheme.primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Conversations Yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: BloodAppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'When a blood request is accepted,\nyou can chat with the other party here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: BloodAppTheme.textSecondary,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Could not load conversations',
              style: TextStyle(color: BloodAppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text(
                'Try Again',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: BloodAppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chat Tile Widget - Shows individual chat preview
class _ChatTile extends StatelessWidget {
  final String threadId;
  final Map<String, dynamic> threadData;
  final String currentUserId;

  const _ChatTile({
    required this.threadId,
    required this.threadData,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getChatDetails(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildLoadingTile();
        }

        final details = snapshot.data!;
        final otherUserName = details['otherUserName'] ?? 'User';
        final bloodType = details['bloodType'] ?? '';
        final units = details['units'] ?? 0;
        final lastMessage = threadData['lastMessage'] ?? 'Start chatting...';
        final lastMessageAt = threadData['lastMessageAt'] as Timestamp?;
        final lastSenderId = threadData['lastSenderId'];
        final isUnread =
            lastSenderId != currentUserId &&
            (threadData['lastReadBy_$currentUserId'] == null ||
                (lastMessageAt != null &&
                    (threadData['lastReadBy_$currentUserId'] as Timestamp)
                            .compareTo(lastMessageAt) <
                        0));

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color:
                isUnread
                    ? BloodAppTheme.primary.withOpacity(0.05)
                    : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openChat(context, details),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Avatar with blood type
                    Stack(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                BloodAppTheme.accent,
                                BloodAppTheme.accentDark,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              otherUserName.isNotEmpty
                                  ? otherUserName.substring(0, 1).toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                          ),
                        ),
                        if (bloodType.isNotEmpty)
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: BloodAppTheme.primary,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                bloodType,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),

                    // Chat details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  otherUserName,
                                  style: TextStyle(
                                    fontWeight:
                                        isUnread
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                    fontSize: 16,
                                    color: BloodAppTheme.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (lastMessageAt != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  _formatTime(lastMessageAt.toDate()),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        isUnread
                                            ? BloodAppTheme.primary
                                            : BloodAppTheme.textHint,
                                    fontWeight:
                                        isUnread
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (lastSenderId == currentUserId)
                                Icon(
                                  Icons.done_all,
                                  size: 14,
                                  color: BloodAppTheme.textHint,
                                ),
                              if (lastSenderId == currentUserId)
                                const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  lastMessage,
                                  style: TextStyle(
                                    color:
                                        isUnread
                                            ? BloodAppTheme.textPrimary
                                            : BloodAppTheme.textSecondary,
                                    fontSize: 14,
                                    fontWeight:
                                        isUnread
                                            ? FontWeight.w500
                                            : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isUnread) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: BloodAppTheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (units > 0) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: BloodAppTheme.info.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$units unit${units > 1 ? 's' : ''} requested',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: BloodAppTheme.info,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: BloodAppTheme.textHint),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingTile() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 14,
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _getChatDetails() async {
    try {
      // Get blood request details
      final requestDoc =
          await FirebaseFirestore.instance
              .collection('blood_requests')
              .doc(threadId)
              .get();

      if (!requestDoc.exists) {
        return {'otherUserName': 'User', 'bloodType': '', 'units': 0};
      }

      final requestData = requestDoc.data()!;
      final bloodType = requestData['bloodType'] ?? '';
      final units = requestData['units'] ?? 0;

      // Determine the other user
      String? otherUserId;
      if (requestData['requesterId'] == currentUserId) {
        // Current user is the requester, other user is the acceptor
        otherUserId = requestData['acceptedBy'];
      } else {
        // Current user is the acceptor, other user is the requester
        otherUserId = requestData['requesterId'];
      }

      String otherUserName = 'User';
      if (otherUserId != null) {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(otherUserId)
                .get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          otherUserName =
              userData['fullName'] ??
              userData['hospitalName'] ??
              userData['bloodBankName'] ??
              'User';
        }
      }

      return {
        'otherUserName': otherUserName,
        'otherUserId': otherUserId,
        'bloodType': bloodType,
        'units': units,
        'requestData': requestData,
      };
    } catch (e) {
      print('Error getting chat details: $e');
      return {'otherUserName': 'User', 'bloodType': '', 'units': 0};
    }
  }

  void _openChat(BuildContext context, Map<String, dynamic> details) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ChatScreen(
              threadId: threadId,
              title: details['otherUserName'] ?? 'Chat',
              subtitle:
                  details['bloodType'] != null &&
                          details['bloodType'].isNotEmpty
                      ? '${details['bloodType']} - ${details['units']} unit(s)'
                      : null,
              otherUserName: details['otherUserName'],
              otherUserId: details['otherUserId'],
              bloodType: details['bloodType'],
              units: details['units'],
            ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      final hour = date.hour > 12 ? date.hour - 12 : date.hour;
      final amPm = date.hour >= 12 ? 'PM' : 'AM';
      return '${hour == 0 ? 12 : hour}:${date.minute.toString().padLeft(2, '0')} $amPm';
    }
    if (dateOnly == yesterday) return 'Yesterday';
    if (now.difference(date).inDays < 7) {
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[date.weekday - 1];
    }
    return '${date.day}/${date.month}/${date.year}';
  }
}
