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
    
    // Handle null createdAt (happens when serverTimestamp hasn't been written yet)
    DateTime createdAtDate;
    final createdAtData = d['createdAt'];
    if (createdAtData is Timestamp) {
      createdAtDate = createdAtData.toDate();
    } else {
      createdAtDate = DateTime.now();
    }
    
    return ChatMessage(
      id: doc.id,
      threadId: (d['threadId'] ?? '') as String,
      senderId: (d['senderId'] ?? '') as String,
      text: (d['text'] ?? '') as String,
      createdAt: createdAtDate,
    );
  }

  Map<String, dynamic> toMap() => {
    'threadId': threadId,
    'senderId': senderId,
    'text': text,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
