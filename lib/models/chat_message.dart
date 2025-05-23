class ChatMessage {
  final int? id;
  final int senderId;
  final int receiverId;
  final String senderName;
  final String receiverName;
  final String message;
  final DateTime sentAt;
  final String? localId;
  final bool isRead;

  ChatMessage({
    this.id,
    required this.senderId,
    required this.receiverId,
    required this.senderName,
    required this.receiverName,
    required this.message,
    required this.sentAt,
    this.localId,
    this.isRead = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      senderId: json['senderId'],
      receiverId: json['receiverId'],
      senderName: json['senderName'],
      receiverName: json['receiverName'],
      message: json['message'],
      sentAt: DateTime.parse(json['sentAt']),
      localId: json['localId'],
      isRead: json['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'senderName': senderName,
      'receiverName': receiverName,
      'message': message,
      'sentAt': sentAt.toIso8601String(),
      'localId': localId,
      'isRead': isRead,
    };
  }
}
