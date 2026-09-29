import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../controller.dart';
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('App Theme', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            'Pick the color you want the app to use',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
          ),
          const SizedBox(height: 16),

          // ---- 5 color swatches to choose from ----
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: List.generate(appThemes.length, (index) {
              final option = appThemes[index];
              final isSelected = themeState.themeIndex == index;

              return GestureDetector(
                onTap: () => notifier.setColor(index),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: option.color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.black87, width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(option.name, style: const TextStyle(fontSize: 11)),
                  ],
                ),
              );
            }),
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 12),

          // ---- Dark mode toggle ----
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Dark Mode'),
            subtitle: const Text('Switch between light and dark appearance'),
            value: themeState.isDark,
            onChanged: notifier.setDark,
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}