import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';

class ChatDialog extends StatefulWidget {
  const ChatDialog({super.key});

  @override
  State<ChatDialog> createState() => _ChatDialogState();
}

class _ChatDialogState extends State<ChatDialog> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  ChatService? _chatService;
  bool _isConnected = false;
  final int _adminId = 1;
  final ScrollController _scrollController = ScrollController();
  bool _isLoggedIn = false;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  void _checkLoginStatus() {
    final user = AuthService.currentUser;
    setState(() {
      _isLoggedIn = user != null;
      _userId = user?['id']; // Lấy ID từ thông tin user đã lưu
      if (_isLoggedIn && _userId != null) {
        _setupChatService();
      } else {
        // Nếu chưa đăng nhập, hiển thị dialog yêu cầu đăng nhập
        _showLoginDialog();
      }
    });
  }

  void _setupChatService() {
    if (_userId == null) return;

    _chatService = ChatService(
      userId: _userId!,
      adminId: _adminId,
      onMessageReceived: _handleMessageReceived,
      onConnectionStateChange: _handleConnectionState,
    );
    _chatService?.connect();
    _loadMessages();
  }

  void _handleMessageReceived(ChatMessage message) {
    setState(() {
      if (!_messages.any((msg) => msg.localId == message.localId)) {
        _messages.add(message);
        _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
      }
    });
    _scrollToBottom();
  }

  void _handleConnectionState(bool connected) {
    setState(() {
      _isConnected = connected;
    });
  }

  Future<void> _loadMessages() async {
    if (_chatService == null) return;

    final messages = await _chatService!.loadMessages();
    setState(() {
      _messages.clear();
      _messages.addAll(messages);
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    if (!_isLoggedIn) {
      _showLoginDialog();
      return;
    }

    if (_messageController.text.trim().isEmpty) return;
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể gửi tin nhắn. Vui lòng thử lại sau.')),
      );
      return;
    }

    _chatService?.sendMessage(_messageController.text.trim());
    _messageController.clear();
  }
  void _showLoginDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Yêu cầu đăng nhập'),
          content: const Text('Bạn cần đăng nhập để sử dụng tính năng chat'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Đóng dialog
                Navigator.pop(context); // Đóng chat
              },
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Đóng dialog
                Navigator.pop(context); // Đóng chat
                Navigator.pushNamed(context, '/login').then((_) {
                  // Sau khi đăng nhập xong, kiểm tra lại trạng thái
                  final user = AuthService.currentUser;
                  if (user != null) {
                    // Nếu đã đăng nhập thành công, mở lại chat
                    showDialog(
                      context: context,
                      builder: (BuildContext context) => const ChatDialog(),
                    );
                  }
                });
              },
              child: const Text('Đăng nhập'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _chatService?.disconnect();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn) {
      return const SizedBox.shrink(); // Không hiện gì nếu chưa đăng nhập
    }

    return Material(
      type: MaterialType.transparency,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.5),
                spreadRadius: 5,
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Chat Support',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isConnected ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
              // Messages
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isUser = message.senderId == _userId;

                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUser ? Colors.blue : Colors.grey[200],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.message,
                              style: TextStyle(
                                color: isUser ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${message.sentAt.hour}:${message.sentAt.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 10,
                                color: isUser ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Input
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Nhập tin nhắn...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      color: Colors.blue,
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
