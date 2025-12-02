import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/chat_service.dart';
import '../../services/fulfillment_service.dart';
import '../../repositories/chat_repository.dart';
import '../../models/chat_message_model.dart';
import '../../core/theme.dart';

/// 💬 PROFESSIONAL REAL-TIME CHAT SCREEN
/// Used for communication between:
/// - Donor ↔ Recipient (after donor accepts)
/// - Blood Bank ↔ Recipient (after blood bank accepts)
/// - Blood Bank ↔ Hospital (after blood bank accepts)
class ChatScreen extends StatefulWidget {
  final String threadId; // equals requestId
  final String title;
  final String? subtitle;
  final String? otherUserName;
  final String? otherUserId;
  final String? bloodType;
  final int? units;

  const ChatScreen({
    super.key,
    required this.threadId,
    required this.title,
    this.subtitle,
    this.otherUserName,
    this.otherUserId,
    this.bloodType,
    this.units,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _chat = ChatService();
  final _ctr = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool _sending = false;
  String? _otherUserName;
  bool _isTyping = false;
  
  // Chat completion state
  bool _isCompleted = false;
  bool _isRequester = false;
  String? _requesterId;

  late AnimationController _sendButtonController;
  late Animation<double> _sendButtonScale;

  @override
  void initState() {
    super.initState();
    _otherUserName = widget.otherUserName;
    _loadOtherUserInfo();
    _markMessagesAsRead();
    _loadThreadInfo();

    _sendButtonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _sendButtonScale = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _sendButtonController, curve: Curves.easeInOut),
    );

    _ctr.addListener(() {
      final hasText = _ctr.text.trim().isNotEmpty;
      if (hasText != _isTyping) {
        setState(() => _isTyping = hasText);
      }
    });
  }

  /// Load thread info to check completion status and requester
  Future<void> _loadThreadInfo() async {
    try {
      final threadDoc = await FirebaseFirestore.instance
          .collection('chat_threads')
          .doc(widget.threadId)
          .get();
      
      if (threadDoc.exists && mounted) {
        final data = threadDoc.data()!;
        setState(() {
          _isCompleted = data['isCompleted'] == true;
          _requesterId = data['requesterId'] as String?;
          _isRequester = _requesterId == _currentUserId;
        });
      }

      // Also check the blood request status as a fallback
      final requestDoc = await FirebaseFirestore.instance
          .collection('blood_requests')
          .doc(widget.threadId)
          .get();
      
      if (requestDoc.exists && mounted) {
        final data = requestDoc.data()!;
        final status = data['status'] as String? ?? '';
        if (status == 'completed') {
          setState(() => _isCompleted = true);
        }
        // Determine if current user is the requester
        final requesterId = data['requesterId'] as String?;
        if (requesterId != null) {
          setState(() {
            _requesterId = requesterId;
            _isRequester = requesterId == _currentUserId;
          });
        }
      }
    } catch (e) {
      print('Error loading thread info: $e');
    }
  }

  @override
  void dispose() {
    _ctr.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _sendButtonController.dispose();
    super.dispose();
  }

  Future<void> _loadOtherUserInfo() async {
    if (widget.otherUserId != null && _otherUserName == null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.otherUserId)
            .get();
        if (doc.exists && mounted) {
          setState(() {
            _otherUserName = doc.data()?['fullName'] ??
                doc.data()?['hospitalName'] ??
                doc.data()?['bloodBankName'] ??
                'User';
          });
        }
      } catch (e) {
        print('Error loading user info: $e');
      }
    }
  }

  Future<void> _markMessagesAsRead() async {
    // Mark thread as read for current user
    try {
      await FirebaseFirestore.instance
          .collection('chat_threads')
          .doc(widget.threadId)
          .set({
        'lastReadBy_$_currentUserId': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  Future<void> _send() async {
    final text = _ctr.text.trim();
    if (text.isEmpty || _sending) return;

    _sendButtonController.forward().then((_) => _sendButtonController.reverse());

    setState(() => _sending = true);
    _ctr.clear();

    try {
      await _chat.send(widget.threadId, text);
      
      // Update thread metadata
      await FirebaseFirestore.instance
          .collection('chat_threads')
          .doc(widget.threadId)
          .set({
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': _currentUserId,
      }, SetOptions(merge: true));

      // Scroll to bottom after sending
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: BloodAppTheme.error,
          ),
        );
        _ctr.text = text; // Restore message on failure
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ChatRepository();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: repo.streamThread(widget.threadId),
        builder: (context, threadSnapshot) {
          // Update completion status from real-time stream
          if (threadSnapshot.hasData && threadSnapshot.data!.exists) {
            final threadData = threadSnapshot.data!.data()!;
            final isCompleted = threadData['isCompleted'] == true;
            final requesterId = threadData['requesterId'] as String?;
            
            // Update state if changed (without calling setState during build)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && (_isCompleted != isCompleted || _requesterId != requesterId)) {
                setState(() {
                  _isCompleted = isCompleted;
                  _requesterId = requesterId;
                  _isRequester = requesterId == _currentUserId;
                });
              }
            });
          }

          return Column(
            children: [
              // Request Info Banner with Complete Button
              _buildRequestInfoBanner(),

              // Messages List
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: repo.streamMessages(widget.threadId),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(BloodAppTheme.primary),
                        ),
                      );
                    }

                    final msgs = snap.data ?? [];

                    if (msgs.isEmpty) {
                      return _buildEmptyState();
                    }

                    // Auto scroll to bottom on new messages
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(
                          _scrollController.position.maxScrollExtent,
                        );
                      }
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: msgs.length,
                      itemBuilder: (context, i) {
                        final m = msgs[i];
                        final isMe = m.senderId == _currentUserId;
                        final showDate = i == 0 ||
                            !_isSameDay(msgs[i - 1].createdAt, m.createdAt);
                        final showAvatar = !isMe &&
                            (i == msgs.length - 1 ||
                                msgs[i + 1].senderId != m.senderId);

                        return Column(
                          children: [
                            if (showDate) _buildDateDivider(m.createdAt),
                            _buildMessageBubble(m, isMe, showAvatar),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              // Input Area (or Completed Banner)
              _isCompleted ? _buildCompletedBanner() : _buildInputArea(),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: BloodAppTheme.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      title: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                (_otherUserName ?? 'U').substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _otherUserName ?? widget.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Online',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showChatOptions(),
        ),
      ],
    );
  }

  Widget _buildRequestInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _isCompleted 
                ? BloodAppTheme.success.withOpacity(0.1)
                : BloodAppTheme.accent.withOpacity(0.1),
            _isCompleted
                ? BloodAppTheme.success.withOpacity(0.05)
                : BloodAppTheme.primary.withOpacity(0.05),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: BloodAppTheme.primary.withOpacity(0.1)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isCompleted 
                      ? BloodAppTheme.success.withOpacity(0.2)
                      : BloodAppTheme.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _isCompleted ? Icons.check_circle : Icons.water_drop,
                  size: 16,
                  color: _isCompleted ? BloodAppTheme.success : BloodAppTheme.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.subtitle ?? 'Blood Request',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: BloodAppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Request ID: ${widget.threadId.substring(0, 8)}...',
                      style: TextStyle(
                        fontSize: 11,
                        color: BloodAppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isCompleted 
                      ? BloodAppTheme.success.withOpacity(0.2)
                      : BloodAppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: BloodAppTheme.success.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _isCompleted 
                            ? BloodAppTheme.success 
                            : BloodAppTheme.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isCompleted ? 'Completed' : 'Accepted',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: BloodAppTheme.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Show "Complete Request" button for requester when not completed
          if (_isRequester && !_isCompleted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showCompleteRequestDialog,
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text('Complete Blood Donation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BloodAppTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Show dialog to confirm completing the blood donation
  Future<void> _showCompleteRequestDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: BloodAppTheme.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: BloodAppTheme.success),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Complete Donation?'),
            ),
          ],
        ),
        content: const Text(
          'Confirm that you have received the blood donation successfully. '
          'This will mark the request as completed and disable further messaging.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: BloodAppTheme.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _completeRequest();
    }
  }

  /// Complete the blood request
  Future<void> _completeRequest() async {
    try {
      // Get the blood request details first
      final requestDoc = await FirebaseFirestore.instance
          .collection('blood_requests')
          .doc(widget.threadId)
          .get();

      if (!requestDoc.exists) {
        throw Exception('Request not found');
      }

      final requestData = requestDoc.data()!;
      final acceptedBy = requestData['acceptedBy'] as String?;
      final acceptedByType = requestData['acceptedByType'] as String?;
      final bloodType = requestData['bloodType'] as String? ?? '';
      final units = (requestData['units'] as num?)?.toInt() ?? 1;
      final requesterName = requestData['requesterName'] as String? ?? 'Requester';

      // Update blood request status
      await FirebaseFirestore.instance
          .collection('blood_requests')
          .doc(widget.threadId)
          .update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Mark chat thread as completed
      await ChatRepository().markThreadAsCompleted(widget.threadId);

      // If accepted by a blood bank, send inventory deduction notification
      if (acceptedBy != null && acceptedByType == 'blood_bank') {
        await FulfillmentService.instance.requestInventoryDeductionConfirmation(
          requestId: widget.threadId,
          bloodBankId: acceptedBy,
          bloodType: bloodType,
          units: units,
          requesterName: requesterName,
        );
      }

      if (mounted) {
        setState(() => _isCompleted = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Blood donation completed! 🎉')),
              ],
            ),
            backgroundColor: BloodAppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete request: $e'),
            backgroundColor: BloodAppTheme.error,
          ),
        );
      }
    }
  }

  /// Build the completed banner shown when chat is disabled
  Widget _buildCompletedBanner() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 16 : 32,
      ),
      decoration: BoxDecoration(
        color: BloodAppTheme.success.withOpacity(0.1),
        border: Border(
          top: BorderSide(color: BloodAppTheme.success.withOpacity(0.3)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 18,
              color: BloodAppTheme.success.withOpacity(0.8),
            ),
            const SizedBox(width: 8),
            Text(
              'Donation completed • Chat is now read-only',
              style: TextStyle(
                color: BloodAppTheme.success.withOpacity(0.8),
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
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
              padding: const EdgeInsets.all(24),
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
                size: 56,
                color: BloodAppTheme.primary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Start the Conversation',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: BloodAppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send a message to coordinate\nthe blood donation details',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: BloodAppTheme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            _buildQuickMessageChips(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickMessageChips() {
    final quickMessages = [
      'Hello! 👋',
      'When can we meet?',
      'What\'s the location?',
      'Thank you!',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: quickMessages.map((msg) {
        return ActionChip(
          label: Text(
            msg,
            style: const TextStyle(fontSize: 12),
          ),
          backgroundColor: BloodAppTheme.surface,
          side: BorderSide(color: BloodAppTheme.primary.withOpacity(0.3)),
          onPressed: () {
            _ctr.text = msg;
            _send();
          },
        );
      }).toList(),
    );
  }

  Widget _buildDateDivider(DateTime? date) {
    final dateStr = date != null ? _formatDate(date) : 'Unknown';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.grey.shade300,
                  ],
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              dateStr,
              style: TextStyle(
                fontSize: 11,
                color: BloodAppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey.shade300,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe, bool showAvatar) {
    return Padding(
      padding: EdgeInsets.only(
        top: 2,
        bottom: 2,
        left: isMe ? 50 : 0,
        right: isMe ? 0 : 50,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showAvatar) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [BloodAppTheme.accent, BloodAppTheme.accentDark],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  (_otherUserName ?? 'U').substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ] else if (!isMe) ...[
            const SizedBox(width: 36),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(
                        colors: [BloodAppTheme.primary, BloodAppTheme.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isMe ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isMe ? BloodAppTheme.primary : Colors.black)
                        .withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isMe ? Colors.white : BloodAppTheme.textPrimary,
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe
                              ? Colors.white.withOpacity(0.7)
                              : BloodAppTheme.textHint,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all,
                          size: 14,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 12 : 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Attachment button
            Container(
              decoration: BoxDecoration(
                color: BloodAppTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.add,
                  color: BloodAppTheme.textSecondary,
                ),
                onPressed: () => _showAttachmentOptions(),
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Text Input
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: BloodAppTheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _focusNode.hasFocus
                        ? BloodAppTheme.primary.withOpacity(0.5)
                        : Colors.transparent,
                  ),
                ),
                child: TextField(
                  controller: _ctr,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: BloodAppTheme.textHint),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Send Button
            ScaleTransition(
              scale: _sendButtonScale,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  gradient: _isTyping
                      ? const LinearGradient(
                          colors: [
                            BloodAppTheme.primary,
                            BloodAppTheme.primaryDark
                          ],
                        )
                      : null,
                  color: _isTyping ? null : BloodAppTheme.surface,
                  shape: BoxShape.circle,
                  boxShadow: _isTyping
                      ? [
                          BoxShadow(
                            color: BloodAppTheme.primary.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: IconButton(
                  icon: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          color: _isTyping
                              ? Colors.white
                              : BloodAppTheme.textSecondary,
                          size: 22,
                        ),
                  onPressed: _sending || !_isTyping ? null : _send,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: BloodAppTheme.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.info, color: BloodAppTheme.info),
                ),
                title: const Text('Request Details'),
                subtitle: const Text('View blood request information'),
                onTap: () {
                  Navigator.pop(context);
                  // Show request details
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: BloodAppTheme.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      const Icon(Icons.report, color: BloodAppTheme.warning),
                ),
                title: const Text('Report Issue'),
                subtitle: const Text('Report a problem with this chat'),
                onTap: () {
                  Navigator.pop(context);
                  // Report issue
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAttachmentOption(
                      Icons.location_on,
                      'Location',
                      BloodAppTheme.success,
                      () {
                        Navigator.pop(context);
                        _ctr.text = '📍 Sharing my location...';
                        _send();
                      },
                    ),
                    _buildAttachmentOption(
                      Icons.phone,
                      'Call',
                      BloodAppTheme.info,
                      () {
                        Navigator.pop(context);
                        // Initiate call
                      },
                    ),
                    _buildAttachmentOption(
                      Icons.access_time,
                      'Schedule',
                      BloodAppTheme.warning,
                      () {
                        Navigator.pop(context);
                        _ctr.text = '🕐 Can we schedule a time to meet?';
                        _send();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentOption(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: BloodAppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime? d1, DateTime? d2) {
    if (d1 == null || d2 == null) return false;
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'Today';
    if (dateOnly == yesterday) return 'Yesterday';

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '${hour == 0 ? 12 : hour}:${date.minute.toString().padLeft(2, '0')} $amPm';
  }
}
