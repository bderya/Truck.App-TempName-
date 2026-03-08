/// One chat message in a booking (messages table).
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.bookingId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.readAt,
  });

  final int id;
  final int bookingId;
  final int senderId;
  final String content;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  static ChatMessage fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int,
      bookingId: json['booking_id'] as int,
      senderId: json['sender_id'] as int,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'booking_id': bookingId,
        'sender_id': senderId,
        'content': content,
        'created_at': createdAt.toIso8601String(),
        if (readAt != null) 'read_at': readAt!.toIso8601String(),
      };
}
