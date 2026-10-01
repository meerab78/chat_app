import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GroupMemberInfo {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;

  const GroupMemberInfo({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
  });
}

class GroupInfo {
  final String name;
  final String? avatarUrl;
  final String? createdBy; // the admin's user id
  final bool iLeft; // true if I already left this group
  final List<GroupMemberInfo> members; // only people still in the group

  const GroupInfo({
    required this.name,
    required this.avatarUrl,
    required this.createdBy,
    required this.iLeft,
    required this.members,
  });
}

// Everything the Group Info screen needs, in one provider.
final groupInfoProvider =
FutureProvider.autoDispose.family<GroupInfo, String>((ref, chatId) async {
  final supabase = Supabase.instance.client;
  final myId = supabase.auth.currentUser!.id;

  final chat = await supabase
      .from('chats')
      .select('name, avatar_url, created_by')
      .eq('id', chatId)
      .single();

  final rows = await supabase
      .from('chat_members')
      .select('user_id, left_at, profiles!inner(name, email, avatar_url)')
      .eq('chat_id', chatId);

  final createdBy = chat['created_by'] as String?;
  final members = <GroupMemberInfo>[];
  bool iLeft = false;

  for (final row in rows) {
    final userId = row['user_id'] as String;

    // People who left are not shown in the members list
    if (row['left_at'] != null) {
      if (userId == myId) iLeft = true;
      continue;
    }

    final profile = row['profiles'];
    members.add(GroupMemberInfo(
      id: userId,
      name: profile['name'] as String? ?? '',
      email: profile['email'] as String? ?? '',
      avatarUrl: profile['avatar_url'] as String?,
    ));
  }

  // Admin first, everyone else A-Z
  members.sort((a, b) {
    if (a.id == createdBy) return -1;
    if (b.id == createdBy) return 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  return GroupInfo(
    name: chat['name'] as String? ?? 'Group',
    avatarUrl: chat['avatar_url'] as String?,
    createdBy: createdBy,
    iLeft: iLeft,
    members: members,
  );
});

// Has the current user left this group? Used by the chat screen.
final hasLeftGroupProvider =
FutureProvider.autoDispose.family<bool, String>((ref, chatId) async {
  final supabase = Supabase.instance.client;

  final row = await supabase
      .from('chat_members')
      .select('left_at')
      .eq('chat_id', chatId)
      .eq('user_id', supabase.auth.currentUser!.id)
      .maybeSingle();

  return row != null && row['left_at'] != null;
});