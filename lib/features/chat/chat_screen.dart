import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../models/models.dart';

/// Quick-reply preset messages (one-tap send).
const List<String> _quickReplies = [
  'I am here',
  'On my way',
  'Almost there',
  'Please wait',
  'At pickup location',
  'Thank you',
];

/// Chat screen for an active booking. Realtime messages, quick replies, call button, read status.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.bookingId,
    required this.currentUserId,
    this.otherPartyPhone,
    this.otherPartyName,
  });

  final int bookingId;
  final int currentUserId;
  /// E.164 or diallable number for the call button. If null, fetched from booking.
  final String? otherPartyPhone;
  final String? otherPartyName;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _loading = true;
  StreamSubscription<ChatMessage>? _subscription;
  String? _resolvedPhone;
  String? _resolvedName;

  @override
  void initState() {
    super.initState();
    _resolvedPhone = widget.otherPartyPhone;
    _resolvedName = widget.otherPartyName;
    _loadAndSubscribe();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    ref.read(chatServiceProvider).markAsRead(widget.bookingId, widget.currentUserId);
    super.dispose();
  }

  Future<void> _loadAndSubscribe() async {
    if (_resolvedPhone == null) {
      final b = await Supabase.instance.client
          .from('bookings')
          .select('client_id, driver_id')
          .eq('id', widget.bookingId)
          .maybeSingle();
      if (b != null && mounted) {
        final otherId = widget.currentUserId == b['client_id']
            ? b['driver_id'] as int?
            : b['client_id'] as int?;
        if (otherId != null) {
          final u = await Supabase.instance.client
              .from('users')
              .select('phone_number, full_name')
              .eq('id', otherId)
              .maybeSingle();
          if (u != null && mounted) {
            _resolvedPhone = u['phone_number'] as String?;
            _resolvedName = u['full_name'] as String?;
          }
        }
      }
    }

    final chat = ref.read(chatServiceProvider);
    final list = await chat.getMessages(widget.bookingId);
    if (!mounted) return;
    setState(() {
      _messages = list;
      _loading = false;
    });
    await chat.markAsRead(widget.bookingId, widget.currentUserId);

    _subscription = chat.watchMessages(widget.bookingId).listen((msg) {
      if (!mounted) return;
      setState(() {
        final i = _messages.indexWhere((m) => m.id == msg.id);
        if (i >= 0) {
          _messages[i] = msg;
        } else {
          _messages.add(msg);
        }
      });
      _scrollToEnd();
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    final chat = ref.read(chatServiceProvider);
    final msg = await chat.sendMessage(
      bookingId: widget.bookingId,
      senderId: widget.currentUserId,
      content: t,
    );
    if (msg != null && mounted) {
      setState(() => _messages.add(msg));
      _scrollToEnd();
    }
  }

  Future<void> _onCall() async {
    final phone = _resolvedPhone ?? widget.otherPartyPhone;
    if (phone == null || phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone number not available')),
        );
      }
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot place call')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_resolvedName ?? widget.otherPartyName ?? 'Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: _onCall,
            tooltip: 'Voice call',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final msg = _messages[i];
                      final isMe = msg.senderId == widget.currentUserId;
                      return _MessageBubble(
                        message: msg,
                        isMe: isMe,
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _quickReplies.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final reply = _quickReplies[i];
                      return ActionChip(
                        label: Text(reply),
                        onPressed: () => _send(reply),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        decoration: const InputDecoration(
                          hintText: 'Message...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: _send,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () {
                        _send(_textController.text);
                        _textController.clear();
                      },
                      icon: const Icon(Icons.send),
                      tooltip: 'Send',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
  });

  final ChatMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isMe
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.content,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _time(message.createdAt),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 6),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.isRead
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _time(DateTime d) {
    final now = DateTime.now();
    if (d.day == now.day && d.month == now.month && d.year == now.year) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
