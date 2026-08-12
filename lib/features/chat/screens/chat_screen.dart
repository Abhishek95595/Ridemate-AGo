import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatScreen extends StatefulWidget {
  final String bookingId;
  final String otherUserName;
  final String otherUserPhone;

  const ChatScreen({
    super.key,
    required this.bookingId,
    required this.otherUserName,
    this.otherUserPhone = '',
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const Color primaryColor = Color(0xFF14B8A6);

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isSending = false;

  CollectionReference<Map<String, dynamic>> get _messagesCollection {
    return _firestore
        .collection('chats')
        .doc(widget.bookingId)
        .collection('messages');
  }

  Future<void> _sendMessage() async {
    final String message = _messageController.text.trim();
    final User? currentUser = _auth.currentUser;

    if (message.isEmpty ||
        currentUser == null ||
        widget.bookingId.trim().isEmpty ||
        _isSending) {
      return;
    }

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await _messagesCollection.add({
        'senderId': currentUser.uid,
        'senderName':
            currentUser.displayName ?? currentUser.email ?? 'AGo User',
        'text': message,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _scrollToBottom();
    } catch (error) {
      _messageController.text = message;
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: message.length),
      );
      _showSnackBar('Could not send message. Please try again.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Sending...';
    final DateTime dateTime = timestamp.toDate();
    final int hour = dateTime.hour;
    final int minute = dateTime.minute;
    final String period = hour >= 12 ? 'PM' : 'AM';
    final int formattedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$formattedHour:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _callOtherUser() async {
    if (widget.otherUserPhone.trim().isEmpty) {
      _showSnackBar('Phone number is unavailable.');
      return;
    }
    final uri = Uri.parse('tel:${widget.otherUserPhone}');
    try {
      if (!await launchUrl(uri)) _showSnackBar('Could not open dialer.');
    } catch (e) {
      _showSnackBar('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentUserId = _auth.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: primaryColor.withValues(alpha: 0.12),
              child: Text(
                _getInitial(widget.otherUserName),
                style: const TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName.isEmpty
                        ? 'AGo User'
                        : widget.otherUserName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Row(
                    children: [
                      CircleAvatar(
                        radius: 3,
                        backgroundColor: Color(0xFF00A884),
                      ),
                      SizedBox(width: 5),
                      Text('Ride conversation', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _callOtherUser,
            icon: const Icon(Icons.call_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _messagesCollection
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return _buildErrorState();
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) return _buildEmptyState();
                _scrollToBottom();
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final bool isMine = data['senderId'] == currentUserId;
                    return _buildMessageBubble(
                      message: (data['text'] ?? '').toString(),
                      senderName: (data['senderName'] ?? 'User').toString(),
                      isMine: isMine,
                      createdAt: data['createdAt'] is Timestamp
                          ? data['createdAt'] as Timestamp
                          : null,
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required String message,
    required String senderName,
    required bool isMine,
    required Timestamp? createdAt,
  }) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(left: 7, bottom: 4),
                child: Text(
                  senderName,
                  style: TextStyle(
                    color: primaryColor.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: BoxDecoration(
                color: isMine ? primaryColor : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMine ? 18 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 18),
                ),
                border: isMine
                    ? null
                    : Border.all(color: const Color(0xFFE8E8EF)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      color: isMine ? Colors.white : Colors.black87,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(createdAt),
                        style: TextStyle(
                          color: isMine ? Colors.white70 : Colors.black54,
                          fontSize: 9.5,
                        ),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.done_all_rounded,
                          size: 14,
                          color: Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3F7),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE5E5EC)),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Write a message...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send_rounded, color: primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            color: primaryColor.withValues(alpha: 0.2),
            size: 80,
          ),
          const SizedBox(height: 20),
          const Text(
            'Start the conversation',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() =>
      const Center(child: Text('Unable to load messages'));

  String _getInitial(String name) =>
      name.isNotEmpty ? name.trim()[0].toUpperCase() : 'U';
}
