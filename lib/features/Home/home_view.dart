import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/shared/widgets/chat_tile.dart';
import '../../core/utils/app_dialogs.dart';
import '../../core/utils/time_formatter.dart';
import '../chats/providers/chat_actions_provider.dart';
import '../chats/providers/chat_list_provider.dart';
import '../chats/providers/chat_list_refresh_provider.dart';
import '../chats/screens/conversation_screens.dart';
import '../chats/screens/create_group_screen.dart';
import '../chats/screens/new_chat_screen.dart';

const Color kAccentColor = Color(0xFF25D366);
const Color kHeaderColor = Color(0xFF075E54);

Color avatarColorFor(String name) {
  const colors = [
    Colors.indigo,
    Colors.deepOrange,
    Colors.teal,
    Colors.purple,
    Colors.blueGrey,
    Colors.pink,
  ];
  if (name.isEmpty) return colors[0];
  int index = name.codeUnitAt(0) % colors.length;
  return colors[index];
}

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  // Sirf UI ke liye: search text
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showNewChatOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ChatUi.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                _sheetOption(
                  icon: Icons.person_outline_rounded,
                  title: 'New Chat',
                  subtitle: 'Message someone directly',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NewChatScreen()),
                    );
                  },
                ),
                _sheetOption(
                  icon: Icons.group_outlined,
                  title: 'New Group',
                  subtitle: 'Create a group with multiple people',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CreateGroupScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: ChatUi.accent.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: ChatUi.accentDark),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, color: ChatUi.ink),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: ChatUi.muted, fontSize: 13),
      ),
    );
  }

  Future<void> _deleteChat(
      BuildContext context, WidgetRef ref, dynamic chat) async {
    final name = chat.otherUserName ?? 'this chat';

    final confirmed = await AppDialogs.confirmDeleteChat(context, name);
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(chatActionsProvider).clearChatForMe(chat.id);
      ref.invalidate(chatListProvider);
    } catch (e) {
      debugPrint('clearChatForMe error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text('Failed to delete chat: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(chatListProvider);
    ref.watch(chatListRefresherProvider);

    final List<Widget> chatSlivers = chatsAsync.when(
      data: (chats) {
        if (chats.isEmpty) {
          return <Widget>[
            const SliverFillRemaining(
              hasScrollBody: false,
              child: ChatEmptyState(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'No chats yet',
                subtitle: 'Tap the button below to start one.',
              ),
            ),
          ];
        }

        // Local search (provider ko touch nahi karta)
        final String q = _query.trim().toLowerCase();
        final visible = chats.where((c) {
          final String n =
          (c.otherUserName ?? 'Unknown').toString().toLowerCase();
          return q.isEmpty || n.contains(q);
        }).toList();

        if (visible.isEmpty) {
          return <Widget>[
            const SliverFillRemaining(
              hasScrollBody: false,
              child: ChatEmptyState(
                icon: Icons.search_off_rounded,
                title: 'No results',
                subtitle: 'Try a different name.',
              ),
            ),
          ];
        }

        return <Widget>[
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, i) {
                  if (i.isOdd) return const ChatDivider();

                  final int idx = i ~/ 2;
                  final chat = visible[idx];
                  final name = chat.otherUserName ?? 'Unknown';

                  // Swipe left = delete (long press bhi pehle jaisa chalega)
                  return Dismissible(
                    key: ValueKey('chat_${chat.id}'),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) async {
                      await _deleteChat(context, ref, chat);
                      return false; // list provider refresh karega
                    },
                    background: Container(
                      color: Colors.red.shade400,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: Colors.white),
                    ),
                    child: ChatTile(
                      index: idx,
                      name: name,
                      lastMessage: chat.lastMessage,
                      time: chat.lastMessageAt != null
                          ? formatMessageTime(chat.lastMessageAt!)
                          : null,
                      unreadCount: chat.unreadCount,
                      isGroup: chat.isGroup,
                      avatarColor:
                      chat.isGroup ? Colors.teal : avatarColorFor(name),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ConversationScreen(
                            chatId: chat.id,
                            otherUserName: name,
                            isGroup: chat.isGroup,
                          ),
                        ),
                      ),
                      onLongPress: () => _deleteChat(context, ref, chat),
                    ),
                  );
                },
                childCount: visible.length * 2 - 1,
              ),
            ),
          ),
        ];
      },
      loading: () => <Widget>[
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: kHeaderColor,
            ),
          ),
        ),
      ],
      error: (err, stack) => <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: ChatErrorState(error: err),
        ),
      ],
    );

    return PopScope(
      canPop: false, // we decide when the app closes
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await AppDialogs.confirmExit(context);
        if (shouldExit) SystemNavigator.pop(); // closes the app
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        floatingActionButton: FloatingActionButton(
          backgroundColor: kAccentColor,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NewChatScreen()),
            );
          },
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            ChatUi.sliverHeader('Chats'),
            SliverToBoxAdapter(
              child: ChatSearchField(
                controller: _searchController,
                hint: 'Search chats',
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            ...chatSlivers,
          ],
        ),
      ),
    );
  }
}