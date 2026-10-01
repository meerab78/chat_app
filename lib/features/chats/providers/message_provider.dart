import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/messages_model.dart';

// autoDispose: forget everything when the chat screen closes,
// so the next time it opens it reads the latest cleared_at / left_at
final messagesProvider = StreamProvider.autoDispose
    .family<List<MessageModel>, String>((ref, chatId) async* {
  final supabase = Supabase.instance.client;
  final currentUserId = supabase.auth.currentUser!.id;

  final membership = await supabase
      .from('chat_members')
      .select('cleared_at, left_at')
      .eq('chat_id', chatId)
      .eq('user_id', currentUserId)
      .maybeSingle();

  final clearedAt = membership != null && membership['cleared_at'] != null
      ? DateTime.parse(membership['cleared_at'] as String)
      : null;

  // Set when I left this group
  final leftAt = membership != null && membership['left_at'] != null
      ? DateTime.parse(membership['left_at'] as String)
      : null;

  // NEW: if I left this group, I should not see any of its messages
  if (leftAt != null) {
    yield <MessageModel>[];
    return;
  }

  final stream = supabase
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('chat_id', chatId)
      .order('created_at')
      .map((rows) => rows.map((json) => MessageModel.fromJson(json)).toList());

  yield* stream.map((messages) {
    // Remove duplicates that have the same id
    final seenIds = <String>{};
    final uniqueMessages = <MessageModel>[];
    for (final m in messages) {
      if (seenIds.add(m.id)) {
        uniqueMessages.add(m);
      }
    }

    // CHANGED: the old leftAt check is gone (not needed anymore)
    if (clearedAt == null) return uniqueMessages;
    return uniqueMessages.where((m) => m.createdAt.isAfter(clearedAt)).toList();
  });
});