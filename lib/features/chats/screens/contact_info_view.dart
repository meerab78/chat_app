import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/shared/widgets/avatar_viewer_screen.dart';
import '../../auth/Profile/other_user_profile_provider.dart';


class ContactInfoScreen extends ConsumerWidget {
  final String chatId;
  const ContactInfoScreen({super.key, required this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(themeProvider).preset;
    final profileAsync = ref.watch(otherUserProfileProvider(chatId));

    return Scaffold(
      backgroundColor: p.background,
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('User not found'));
          }
          final avatarUrl = profile.avatarUrl;
          final name = profile.name;

          return CustomScrollView(
            slivers: [
              // ---- Colored header with big avatar ----
              SliverAppBar(
                pinned: true,
                backgroundColor: p.header,
                foregroundColor: Colors.white,
                expandedHeight: 280,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(color: p.header),
                    padding: const EdgeInsets.only(top: 60, bottom: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: avatarUrl != null
                              ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AvatarViewerScreen(
                                imageUrl: avatarUrl,
                                title: name,
                              ),
                            ),
                          )
                              : null,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 16,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 64,
                              backgroundColor: Colors.white,
                              backgroundImage:
                              avatarUrl != null ? NetworkImage(avatarUrl) : null,
                              child: avatarUrl == null
                                  ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TextStyle(
                                  fontSize: 46,
                                  fontWeight: FontWeight.bold,
                                  color: p.header,
                                ),
                              )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (profile.username != null && profile.username!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '@${profile.username}',
                            style: const TextStyle(fontSize: 14, color: Colors.white70),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // ---- Info sections ----
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                        _InfoCard(
                          icon: Icons.info_outline,
                          label: 'About',
                          value: profile.bio!,
                          accent: p.primary,
                          surface: p.surface,
                          textMain: p.textMain,
                          textGrey: p.textGrey,
                        ),
                        const SizedBox(height: 12),
                      ],
                      _InfoCard(
                        icon: Icons.mail_outline,
                        label: 'Email',
                        value: profile.email,
                        accent: p.primary,
                        surface: p.surface,
                        textMain: p.textMain,
                        textGrey: p.textGrey,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

// One rounded info card: icon + label + value
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final Color surface;
  final Color textMain;
  final Color textGrey;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.surface,
    required this.textMain,
    required this.textGrey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: textGrey, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(fontSize: 15, color: textMain),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}