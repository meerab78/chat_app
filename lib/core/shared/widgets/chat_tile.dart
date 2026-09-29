import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatUi {
  static const Color ink = Color(0xFF111B21);
  static const Color muted = Color(0xFF667781);
  static const Color line = Color(0xFFEDEFF0);
  static const Color surface = Color(0xFFF3F5F4);
  static const Color accent = Color(0xFF25D366);
  static const Color accentDark = Color(0xFF075E54);

  static Widget sliverHeader(String title) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      toolbarHeight: 48,
      expandedHeight: 68, // pehle 96 tha, isi se upar ka space kam hua
      flexibleSpace: FlexibleSpaceBar(
        expandedTitleScale: 1.35,
        titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 10),
        title: Text(
          title,
          style: const TextStyle(
            color: ink,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
      ),
    );
  }
}

// ---------- Search field ----------
class ChatSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  const ChatSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Search',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 15, color: ChatUi.ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: ChatUi.muted, fontSize: 15),
          prefixIcon: const Icon(Icons.search_rounded, color: ChatUi.muted),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 20, color: ChatUi.muted),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              );
            },
          ),
          filled: true,
          fillColor: ChatUi.surface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ---------- Filter chips ----------
class ChatFilterChips extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  const ChatFilterChips({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final bool isSelected = i == selected;
          return GestureDetector(
            onTap: () => onSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? ChatUi.accentDark : ChatUi.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : ChatUi.muted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------- Chat tile ----------
class ChatTile extends StatelessWidget {
  final String name;
  final String? lastMessage;
  final String? time;
  final int unreadCount;
  final bool isGroup;
  final Color avatarColor;
  final int index; // sirf halki entry animation ke liye
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ChatTile({
    super.key,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.isGroup,
    required this.avatarColor,
    required this.onTap,
    this.index = 0,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasUnread = unreadCount > 0;
    final String badge = unreadCount > 99 ? '99+' : '$unreadCount';
    final int ms = 220 + (index < 10 ? index : 10) * 40;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              // Avatar (unread ho to green ring)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: hasUnread ? ChatUi.accent : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: avatarColor.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: isGroup
                      ? Icon(Icons.groups_rounded, color: avatarColor, size: 24)
                      : Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: avatarColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Name + last message
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ChatUi.ink,
                        fontSize: 16,
                        fontWeight:
                        hasUnread ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lastMessage ?? 'No messages yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasUnread ? ChatUi.ink : ChatUi.muted,
                        fontSize: 14,
                        fontWeight:
                        hasUnread ? FontWeight.w500 : FontWeight.normal,
                        fontStyle: lastMessage == null
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Time + unread badge
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (time != null)
                    Text(
                      time!,
                      style: TextStyle(
                        fontSize: 12,
                        color: hasUnread ? ChatUi.accentDark : ChatUi.muted,
                        fontWeight:
                        hasUnread ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                  if (hasUnread) ...[
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: ChatUi.accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatDivider extends StatelessWidget {
  const ChatDivider({super.key});

  @override
  Widget build(BuildContext context) {
    // 20 (padding) + 56 (avatar) + 14 (gap) = 90
    return const Divider(
        height: 1, thickness: 1, indent: 90, color: ChatUi.line);
  }
}

// ---------- Empty / Error ----------
class ChatEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const ChatEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: ChatUi.accent.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: ChatUi.accentDark),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                color: ChatUi.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ChatUi.muted,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatErrorState extends StatelessWidget {
  final Object error;
  const ChatErrorState({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 44, color: Colors.red.shade300),
            const SizedBox(height: 12),
            const Text(
              'Something went wrong',
              style: TextStyle(
                color: ChatUi.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$error',
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ChatUi.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}