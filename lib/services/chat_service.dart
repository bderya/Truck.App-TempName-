import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Fetches and streams chat messages for a booking; sends messages; marks as read.
class ChatService {
  ChatService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  RealtimeChannel? _channel;

  /// List of messages for [bookingId], ordered by [created_at].
  Future<List<ChatMessage>> getMessages(int bookingId) async {
    final res = await _client
        .from('messages')
        .select()
        .eq('booking_id', bookingId)
        .order('created_at', ascending: true);
    return (res as List<dynamic>)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Stream of new/updated messages for [bookingId]. Filtered by booking_id on client.
  Stream<ChatMessage> watchMessages(int bookingId) async* {
    final controller = StreamController<ChatMessage>.broadcast();
    _channel?.unsubscribe();
    _channel = _client
        .channel('messages-$bookingId')
        .onPostgresChanges(
          schema: 'public',
          table: 'messages',
          event: PostgresChangeEvent.insert,
          callback: (payload) {
            final record = payload.newRecord;
            if (record == null) return;
            final bid = record['booking_id'] as int?;
            if (bid == bookingId) {
              controller.add(ChatMessage.fromJson(record as Map<String, dynamic>));
            }
          },
        )
        .onPostgresChanges(
          schema: 'public',
          table: 'messages',
          event: PostgresChangeEvent.update,
          callback: (payload) {
            final record = payload.newRecord;
            if (record == null) return;
            final bid = record['booking_id'] as int?;
            if (bid == bookingId) {
              controller.add(ChatMessage.fromJson(record as Map<String, dynamic>));
            }
          },
        );
    _channel?.subscribe();
    yield* controller.stream;
  }

  void _disposeChannel() {
    _channel?.unsubscribe();
    _channel = null;
  }

  /// Send a text message.
  Future<ChatMessage?> sendMessage({
    required int bookingId,
    required int senderId,
    required String content,
  }) async {
    if (content.trim().isEmpty) return null;
    final res = await _client.from('messages').insert({
      'booking_id': bookingId,
      'sender_id': senderId,
      'content': content.trim(),
    }).select().single();
    return ChatMessage.fromJson(res as Map<String, dynamic>);
  }

  /// Mark messages in this booking (from the other party) as read by updating read_at.
  Future<void> markAsRead(int bookingId, int currentUserId) async {
    await _client
        .from('messages')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('booking_id', bookingId)
        .neq('sender_id', currentUserId)
        .is_('read_at', null);
  }

  void dispose() {
    _disposeChannel();
  }
}
