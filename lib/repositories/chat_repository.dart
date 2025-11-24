import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message_model.dart';

class ChatRepository {
  final _threads = FirebaseFirestore.instance.collection('chat_threads');

  // threadId == bloodRequestId for simplicity
  Stream<List<ChatMessage>> streamMessages(String threadId) {
    return _threads
        .doc(threadId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => ChatMessage.fromDoc(d)).toList());
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
    final batch = FirebaseFirestore.instance.batch();

    final threadRef = _threads.doc(threadId);
    batch.set(threadRef, {
      'participants': FieldValue.arrayUnion([senderId]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));

    final msgRef = threadRef.collection('messages').doc();
    batch.set(msgRef, msg.toMap());

    await batch.commit();
  }
}
