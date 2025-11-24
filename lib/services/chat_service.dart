import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/chat_repository.dart';
import '../models/chat_message_model.dart';

class ChatService {
  final _auth = FirebaseAuth.instance;
  final _repo = ChatRepository();

  Stream<List<ChatMessage>> streamMessages(String threadId) =>
      _repo.streamMessages(threadId);

  Future<void> send(String threadId, String text) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');
    if (text.trim().isEmpty) return;
    await _repo.sendMessage(threadId: threadId, senderId: uid, text: text);
  }
}
