import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Talks to Supabase. Nothing here knows about the UI or Riverpod.
// The PIN hash lives in chat_members.lock_pin_hash (one row per user per chat).
class ChatLockService {
  final _db = Supabase.instance.client;

  String get _userId => _db.auth.currentUser!.id;

  // PIN + chatId + userId are mixed, so the same PIN gives a different hash in every chat
  String _hash(String pin, String chatId) {
    final bytes = utf8.encode('$pin:$chatId:$_userId');
    return sha256.convert(bytes).toString();
  }

  // Chats where this user has set a PIN
  Future<Set<String>> getLockedChatIds() async {
    final rows = await _db
        .from('chat_members')
        .select('chat_id')
        .eq('user_id', _userId)
        .not('lock_pin_hash', 'is', null);
    return rows.map((r) => r['chat_id'] as String).toSet();
  }

  // Sets the PIN (or changes it if the chat is already locked)
  Future<void> saveLock(String chatId, String pin) async {
    await _db
        .from('chat_members')
        .update({'lock_pin_hash': _hash(pin, chatId)})
        .eq('chat_id', chatId)
        .eq('user_id', _userId);
  }

  Future<bool> verifyPin(String chatId, String pin) async {
    final row = await _db
        .from('chat_members')
        .select('lock_pin_hash')
        .eq('chat_id', chatId)
        .eq('user_id', _userId)
        .maybeSingle();
    return row != null && row['lock_pin_hash'] == _hash(pin, chatId);
  }

  Future<void> deleteLock(String chatId) async {
    await _db
        .from('chat_members')
        .update({'lock_pin_hash': null})
        .eq('chat_id', chatId)
        .eq('user_id', _userId);
  }
}