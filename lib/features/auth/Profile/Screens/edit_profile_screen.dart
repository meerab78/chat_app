import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/shared/widgets/custom_button.dart';
import '../../../../core/shared/widgets/custom_text_field.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../widget/auth_header.dart';
import '../provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _loadedOnce = false;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Opens the gallery, then uploads the picked image as the new avatar
  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      await ref.read(profileActionsProvider).updateAvatar(File(picked.path));
      ref.invalidate(myProfileProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to update photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(profileActionsProvider).updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      ref.invalidate(myProfileProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    final p = ref.watch(themeProvider).preset;
    final headerColor = p.primary;

    return Scaffold(
      backgroundColor: p.background,
      body: Center(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: profileAsync.when(
              data: (profile) {
                // Fill the fields once, the first time data arrives
                if (!_loadedOnce) {
                  _nameController.text = (profile['name'] as String?) ?? '';
                  _phoneController.text = (profile['phone'] as String?) ?? '';
                  _loadedOnce = true;
                }
                final avatarUrl = profile['avatar_url'] as String?;
                final name = _nameController.text;

                return Column(
                  children: [
                    const AuthHeader(
                      title: 'Profile Settings',
                      showBackButton: true,
                      subtitle: 'Update your photo and personal details.',
                    ),

                    // ---- Avatar with an edit button on top ----
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: headerColor.withOpacity(0.15),
                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null
                              ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: headerColor,
                            ),
                          )
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: headerColor,
                              child: _isUploadingAvatar
                                  ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    CustomTextField(
                      controller: _nameController,
                      hintText: 'Name',
                      prefixIcon: Icons.person_outline,
                    ),
                    const SizedBox(height: 18),
                    CustomTextField(
                      controller: _phoneController,
                      hintText: 'Phone',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 32),

                    CustomButton(
                      text: 'Save Changes',
                      isLoading: _isSaving,
                      onPressed: _save,
                    ),
                    const SizedBox(height: 70),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => Padding(
                padding: const EdgeInsets.only(top: 100),
                child: Center(child: Text('Error: $err')),
              ),
            ),
          ),
        ),
      ),
    );
  }
}