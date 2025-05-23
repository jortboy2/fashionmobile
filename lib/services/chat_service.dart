import 'dart:async';
import 'dart:convert';
import 'package:fashionmobile/services/network_service.dart';
import 'package:http/http.dart' as http;
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import '../models/chat_message.dart';

class ChatService {
  static const String baseUrl = NetworkService.defaultIp;
  static const String wsUrl = '$baseUrl/ws';
  
  late StompClient stompClient;
  final int userId;
  final int adminId;
  final Function(ChatMessage) onMessageReceived;
  final Function(bool) onConnectionStateChange;

  ChatService({
    required this.userId,
    required this.adminId,
    required this.onMessageReceived,
    required this.onConnectionStateChange,
  });

  Future<void> connect() async {
    stompClient = StompClient(
      config: StompConfig.sockJS(
        url: wsUrl,
        onConnect: onConnect,
        onDisconnect: onDisconnect,
        onWebSocketError: (dynamic error) => print('Error: $error'),
        stompConnectHeaders: {
          'Access-Control-Allow-Origin': '*',
        },
        webSocketConnectHeaders: {
          'Access-Control-Allow-Origin': '*',
        },
      ),
    );

    stompClient.activate();
  }

  void onConnect(StompFrame frame) {
    print('Connected to WebSocket');
    onConnectionStateChange(true);

    // Subscribe to private messages
    stompClient.subscribe(
      destination: '/user/$userId/queue/private',
      callback: (frame) {
        if (frame.body != null) {
          final message = ChatMessage.fromJson(jsonDecode(frame.body!));
          onMessageReceived(message);
        }
      },
    );

    // Subscribe to public messages
    stompClient.subscribe(
      destination: '/topic/messages',
      callback: (frame) {
        if (frame.body != null) {
          final message = ChatMessage.fromJson(jsonDecode(frame.body!));
          // Only process messages relevant to this chat
          if ((message.senderId == userId && message.receiverId == adminId) ||
              (message.senderId == adminId && message.receiverId == userId)) {
            onMessageReceived(message);
          }
        }
      },
    );
  }

  void onDisconnect(StompFrame frame) {
    print('Disconnected from WebSocket');
    onConnectionStateChange(false);
  }

  void sendMessage(String message) {
    if (!stompClient.connected) return;

    final chatMessage = ChatMessage(
      senderId: userId,
      receiverId: adminId,
      senderName: 'User', // Replace with actual user name
      receiverName: 'Admin',
      message: message,
      sentAt: DateTime.now(),
      localId: DateTime.now().millisecondsSinceEpoch.toString(),
    );

    stompClient.send(
      destination: '/app/chat.sendMessage',
      body: jsonEncode(chatMessage.toJson()),
      headers: {
        'content-type': 'application/json',
        'sender-id': userId.toString(),
        'receiver-id': adminId.toString(),
        'message-type': 'chat',
      },
    );
  }

  Future<List<ChatMessage>> loadMessages() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/chat/messages/$userId/$adminId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> messages = jsonDecode(response.body);
        return messages
            .map((msg) => ChatMessage.fromJson(msg))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error loading messages: $e');
      return [];
    }
  }

  void disconnect() {
    stompClient.deactivate();
  }
}
