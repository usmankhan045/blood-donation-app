import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String threadId;    // requestId
  final String senderId;
  final String text;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessage.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      threadId: d['threadId'] as String,
      senderId: d['senderId'] as String,
      text: (d['text'] ?? '') as String,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'threadId': threadId,
    'senderId': senderId,
    'text': text,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
