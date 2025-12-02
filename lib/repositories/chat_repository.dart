import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message_model.dart';
import '../services/fcm_service.dart';

class ChatRepository {
  final _threads = FirebaseFirestore.instance.collection('chat_threads');
  final _firestore = FirebaseFirestore.instance;
  final _fcmService = FCMService();

  /// Create or initialize a chat thread when a request is accepted
  /// This should be called when a donor or blood bank accepts a request
  Future<void> initializeChatThread({
    required String threadId, // requestId
    required String requesterId, // recipient or hospital
    required String acceptorId, // donor or blood bank
    required String requesterName,
    required String acceptorName,
    required String bloodType,
    required int units,
    required String acceptorType, // 'donor' or 'blood_bank'
  }) async {
    final threadRef = _threads.doc(threadId);

    await threadRef.set({
      'participants': [requesterId, acceptorId],
      'requesterName': requesterName,
      'acceptorName': acceptorName,
      'requesterId': requesterId,
      'acceptorId': acceptorId,
      'acceptorType': acceptorType,
      'bloodType': bloodType,
      'units': units,
      'isCompleted': false, // Track if request/donation is completed
      'completedAt': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': null,
      'lastMessageAt': null,
      'lastSenderId': null,
    }, SetOptions(merge: true));
  }

  /// Mark a chat thread as completed (donation process finished)
  /// This disables further messaging in the chat
  Future<void> markThreadAsCompleted(String threadId) async {
    await _threads.doc(threadId).update({
      'isCompleted': true,
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Send system message about completion
    await sendSystemMessage(
      threadId: threadId,
      text: '✅ Blood donation completed! Thank you for saving lives. This chat is now read-only.',
    );
  }

  /// Check if a chat thread is completed
  Future<bool> isThreadCompleted(String threadId) async {
    final doc = await _threads.doc(threadId).get();
    if (!doc.exists) return false;
    return doc.data()?['isCompleted'] == true;
  }

  /// Stream the thread document for real-time updates (including completion status)
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamThread(String threadId) {
    return _threads.doc(threadId).snapshots();
  }

  // threadId == bloodRequestId for simplicity
  Stream<List<ChatMessage>> streamMessages(String threadId) {
    return _threads
        .doc(threadId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => ChatMessage.fromDoc(d)).toList());
  }

  /// Get chat threads for a specific user
  Stream<QuerySnapshot> getThreadsForUser(String userId) {
    return _threads
        .where('participants', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  /// Check if a chat thread exists
  Future<bool> threadExists(String threadId) async {
    final doc = await _threads.doc(threadId).get();
    return doc.exists;
  }

  /// Get unread message count for a user in a specific thread
  Future<int> getUnreadCount(String threadId, String userId) async {
    final threadDoc = await _threads.doc(threadId).get();
    if (!threadDoc.exists) return 0;

    final lastReadTimestamp =
        threadDoc.data()?['lastReadBy_$userId'] as Timestamp?;

    Query query = _threads.doc(threadId).collection('messages');

    if (lastReadTimestamp != null) {
      query = query
          .where('createdAt', isGreaterThan: lastReadTimestamp)
          .where('senderId', isNotEqualTo: userId);
    }

    final snapshot = await query.get();
    return snapshot.docs.length;
  }

  Future<void> sendMessage({
    required String threadId,
    required String senderId,
    required String text,
  }) async {
    final msg = ChatMessage(
      id: '',
      threadId: threadId,
      senderId: senderId,
      text: text.trim(),
      createdAt: DateTime.now(),
    );
    final batch = _firestore.batch();

    final threadRef = _threads.doc(threadId);
    batch.set(threadRef, {
      'participants': FieldValue.arrayUnion([senderId]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'lastMessage': text.trim(),
      'lastMessageAt': Timestamp.fromDate(DateTime.now()),
      'lastSenderId': senderId,
    }, SetOptions(merge: true));

    final msgRef = threadRef.collection('messages').doc();
    batch.set(msgRef, msg.toMap());

    await batch.commit();

    // Send push notification to the other user
    await _sendChatNotification(threadId, senderId, text.trim());
  }

  /// Send FCM notification to the other participant in the chat
  Future<void> _sendChatNotification(
    String threadId,
    String senderId,
    String message,
  ) async {
    try {
      // Get thread info
      final threadDoc = await _threads.doc(threadId).get();
      if (!threadDoc.exists) return;

      final threadData = threadDoc.data()!;
      final participants = List<String>.from(threadData['participants'] ?? []);

      // Find the other user
      final recipientId = participants.firstWhere(
        (id) => id != senderId,
        orElse: () => '',
      );

      if (recipientId.isEmpty) return;

      // Get sender name
      final senderDoc =
          await _firestore.collection('users').doc(senderId).get();
      final senderName =
          senderDoc.data()?['fullName'] ??
          senderDoc.data()?['hospitalName'] ??
          senderDoc.data()?['bloodBankName'] ??
          'User';

      // Get recipient FCM token
      final recipientDoc =
          await _firestore.collection('users').doc(recipientId).get();
      final fcmToken = recipientDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null || fcmToken.isEmpty) {
        print('⚠️ Recipient has no FCM token');
        return;
      }

      // Get blood type info from thread
      final bloodType = threadData['bloodType'] as String? ?? '';

      // Send notification
      await _fcmService.sendNotificationWithBackup(
        token: fcmToken,
        title: '💬 New message from $senderName',
        body:
            message.length > 100 ? '${message.substring(0, 100)}...' : message,
        data: {
          'type': 'chat_message',
          'threadId': threadId,
          'senderId': senderId,
          'senderName': senderName,
          'bloodType': bloodType,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Also write to user_notifications inbox for in-app notifications
      await _firestore
          .collection('user_notifications')
          .doc(recipientId)
          .collection('inbox')
          .add({
            'title': '💬 New message from $senderName',
            'body':
                message.length > 100
                    ? '${message.substring(0, 100)}...'
                    : message,
            'type': 'chat_message',
            'threadId': threadId,
            'senderId': senderId,
            'senderName': senderName,
            'bloodType': bloodType,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

      print('✅ Chat notification sent to $recipientId');
    } catch (e) {
      print('❌ Error sending chat notification: $e');
    }
  }

  /// Send a system message (e.g., "Request accepted")
  Future<void> sendSystemMessage({
    required String threadId,
    required String text,
  }) async {
    final msg = ChatMessage(
      id: '',
      threadId: threadId,
      senderId: 'system',
      text: text,
      createdAt: DateTime.now(),
    );

    final batch = _firestore.batch();

    final threadRef = _threads.doc(threadId);
    batch.set(threadRef, {
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'lastMessage': text,
      'lastMessageAt': Timestamp.fromDate(DateTime.now()),
      'lastSenderId': 'system',
    }, SetOptions(merge: true));

    final msgRef = threadRef.collection('messages').doc();
    batch.set(msgRef, msg.toMap());

    await batch.commit();
  }

  /// Mark thread as read by a user
  Future<void> markAsRead(String threadId, String userId) async {
    await _threads.doc(threadId).set({
      'lastReadBy_$userId': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
