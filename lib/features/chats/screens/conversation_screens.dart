import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/app_dialogs.dart';
import '../../../core/utils/app_haptics.dart';
import '../../Home/home_view.dart';
import '../../voice/provider/voice_recorder_provider.dart';
import '../../voice/services/voice_recorder.dart';
import '../../voice/widget/voice_record_widgets.dart';
import '../providers/chat_actions_provider.dart';
import '../providers/message_provider.dart';
import '../providers/group_members_provider.dart';
import '../widgets/message_bubble.dart';
import 'image_preview_view.dart';
class ConversationScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String otherUserName;
  final bool isGroup;


  const ConversationScreen({
    super.key,
    required this.chatId,
    required this.otherUserName,
    this.isGroup = false,
  });

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;
  bool _showAttachPanel = false; // controls the smooth attach panel
  static const int _maxRecordSeconds = 300; //5min
  static const int _maxFileBytes = 5 * 1024 * 1024; // 5 MB
  String get _currentUserId => Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatActionsProvider).markMessagesAsRead(widget.chatId);
    });
    // Rebuild UI whenever text changes, so mic <-> send icon toggles correctly
    _messageController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
  // Called when user presses and holds the mic button
  Future<void> _startVoiceRecording() async {
    final started = await ref.read(voiceRecorderProvider.notifier).start();
    AppHaptics.error();
    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mic permission denied or failed to start')),
      );
    }
  }

  // Called when user lifts the finger (or the time limit is reached)
  Future<void> _stopVoiceRecording() async {
    final result = await ref.read(voiceRecorderProvider.notifier).stop();
    if (!mounted || result == null) return;
    AppHaptics.messageSent();

    await ref.read(chatActionsProvider).sendVoiceMessage(
      chatId: widget.chatId,
      audioFile: File(result.filePath),
      durationSeconds: result.durationSeconds,
    );
  }

  // Slide left or trash button: throw the recording away
  Future<void> _cancelVoiceRecording() async {
    await ref.read(voiceRecorderProvider.notifier).cancel();
    AppHaptics.warning();
  }

  void _lockVoiceRecording() {
    AppHaptics.lock();
    ref.read(voiceRecorderProvider.notifier).lock();
  }

  // Helper to format seconds as m:ss for the live timer
  String _formatRecordTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
  Future<void> _pickAndSendImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1280,
    );
    if (pickedFile == null) return;

    final imageFile = File(pickedFile.path);

    // 5 MB limit check
    final int fileSize = await imageFile.length();
    if (fileSize > _maxFileBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File is too large. Maximum size is 5 MB')),
      );
      return;
    }

    if (!mounted) return;
    AppHaptics.messageSent();

    // Show preview screen first, wait for the caption (or null if cancelled)
    final caption = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ImagePreviewScreen(imageFile: imageFile),
      ),
    );

    // If user pressed back instead of send, caption will be null -> do nothing
    if (caption == null) return;

    await ref.read(chatActionsProvider).sendImageMessage(
      chatId: widget.chatId,
      imageFile: imageFile,
      caption: caption,
    );
  }
  void _toggleAttachPanel() {
    FocusScope.of(context).unfocus(); // hide keyboard first, like WhatsApp
    setState(() => _showAttachPanel = !_showAttachPanel);
  }
  Future<void> _pickAndSendFile() async {
    final PlatformFile? pickedFile = await FilePicker.pickFile();
    if (pickedFile == null || pickedFile.path == null) return;

    final file = File(pickedFile.path!);
    final fileName = pickedFile.name;

    // 5 MB size check, same rule as images
    final int fileSize = await file.length();
    if (fileSize > _maxFileBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File is too large. Maximum size is 5 MB')),
      );
      return;
    }

    AppHaptics.messageSent();
    await ref.read(chatActionsProvider).sendFileMessage(
      chatId: widget.chatId,
      file: file,
      fileName: fileName,
    );
  }
  // First step: "Share current location" or "Share live location"
  void _showLocationOptionsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Share your location',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.location_on, color: Colors.redAccent),
                title: const Text('Share current location'),
                subtitle: const Text('Sends a single pin'),
                onTap: () {
                  Navigator.pop(context);
                  _sendCurrentLocation(null); // null = not live
                },
              ),
              ListTile(
                leading: const Icon(Icons.location_searching, color: Colors.green),
                title: const Text('Share live location'),
                subtitle: const Text('Choose how long, then send'),
                onTap: () {
                  Navigator.pop(context);
                  _showLiveLocationDurationSheet();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

// Second step (only for live location): pick a duration, then press Send
  void _showLiveLocationDurationSheet() {
    int? selectedMinutes; // holds the user's pick until they press Send

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        // StatefulBuilder lets this sheet remember which option is selected
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget durationTile(String label, int minutes) {
              final bool isSelected = selectedMinutes == minutes;
              return ListTile(
                leading: Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: isSelected ? kAccentColor : Colors.grey,
                ),
                title: Text(label),
                onTap: () {
                  setSheetState(() => selectedMinutes = minutes);
                },
              );
            }

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Share live location for...',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  durationTile('15 minutes', 15),
                  durationTile('1 hour', 60),
                  durationTile('8 hours', 480),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        // Send stays disabled until a duration is picked
                        onPressed: selectedMinutes == null
                            ? null
                            : () {
                          Navigator.pop(context);
                          _sendCurrentLocation(selectedMinutes);
                        },
                        child: const Text('Send'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

// liveMinutes == null means a one-time (non-live) location
  Future<void> _sendCurrentLocation(int? liveMinutes) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied')),
      );
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    AppHaptics.messageSent();

    await ref.read(chatActionsProvider).sendLocationMessage(
      chatId: widget.chatId,
      latitude: position.latitude,
      longitude: position.longitude,
      liveDurationMinutes: liveMinutes,
    );
  }

// Called when the sender taps "Stop sharing" on their own live location
  Future<void> _stopLiveLocation(String messageId) async {
    await ref.read(chatActionsProvider).stopLiveLocation(messageId);
    ref.invalidate(messagesProvider(widget.chatId));
  }

// Ek option ka button (gol icon + neeche naam)
  Widget _attachOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: kHeaderColor.withOpacity(0.12),
            child: Icon(icon, color: kHeaderColor, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12.5)),
        ],
      ),
    );
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon')),
    );
  }
  // The actual panel content (grid of options)
  Widget _buildAttachPanel() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 4,
        mainAxisSpacing: 16,
        children: [
          _attachOption(
            icon: Icons.photo_camera,
            label: 'Camera',
            onTap: () {
              setState(() => _showAttachPanel = false);
              _pickAndSendImage(ImageSource.camera);
            },
          ),
          _attachOption(
            icon: Icons.photo_library,
            label: 'Gallery',
            onTap: () {
              setState(() => _showAttachPanel = false);
              _pickAndSendImage(ImageSource.gallery);
            },
          ),
          _attachOption(
            icon: Icons.insert_drive_file,
            label: 'File',
            onTap: () {
              setState(() => _showAttachPanel = false);
              _pickAndSendFile();
            },
          ),
          _attachOption(
            icon: Icons.location_on,
            label: 'Location',
            onTap: () {
              setState(() => _showAttachPanel = false);
              _showLocationOptionsSheet();
            },
          ),
          // _attachOption(
          //   icon: Icons.person,
          //   label: 'Contact',
          //   onTap: () {
          //     setState(() => _showAttachPanel = false);
          //     _showComingSoon();
          //   },
          // ),
        ],
      ),
    );
  }
  Future<void> _sendMessage() async {
    if (_isSending) return; // block double-tap

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    AppHaptics.messageSent();
    _messageController.clear();

    try {
      await ref.read(chatActionsProvider).sendMessage(
        chatId: widget.chatId,
        content: text,
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
  // Long press on my message: ask what to do
  Future<void> _showMessageOptions(dynamic msg) async {
    AppHaptics.medium();

    final action = await AppDialogs.messageOptions(
      context,
      canEdit: msg.messageType == 'text', // voice and image can't be edited
    );
    if (action == null || !mounted) return;

    if (action == MessageAction.edit) {
      await _editMessage(msg);
    } else {
      await _deleteMessage(msg);
    }
  }

  Future<void> _editMessage(dynamic msg) async {
    final newText = await AppDialogs.editText(
      context,
      title: 'Edit message',
      initialText: msg.content,
    );

    // null = cancelled, empty or same text = nothing to save
    if (newText == null || newText.isEmpty || newText == msg.content) return;

    await ref.read(chatActionsProvider).editMessage(
      messageId: msg.id,
      newContent: newText,
    );
    ref.invalidate(messagesProvider(widget.chatId));
  }

  Future<void> _deleteMessage(dynamic msg) async {
    final confirmed = await AppDialogs.confirmDeleteMessage(context);
    if (!confirmed || !mounted) return;

    AppHaptics.warning();
    await ref.read(chatActionsProvider).deleteMessage(msg.id);
    ref.invalidate(messagesProvider(widget.chatId));
  }
  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.chatId));
    // Auto-stop when the recording limit is reached
    ref.listen<VoiceRecorderState>(voiceRecorderProvider, (prev, next) {
      if (next.isRecording && next.seconds >= _maxRecordSeconds) {
        _stopVoiceRecording();
      }
    });
    final recorder = ref.watch(voiceRecorderProvider);
    final groupMembersAsync = widget.isGroup
        ? ref.watch(groupMembersProvider(widget.chatId))
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5), // soft neutral chat background
      appBar: AppBar(
        backgroundColor: kHeaderColor,
        foregroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: widget.isGroup
                  ? Colors.teal.shade100
                  : avatarColorFor(widget.otherUserName),
              child: widget.isGroup
                  ? const Icon(Icons.group, color: Colors.teal, size: 18)
                  : Text(
                widget.otherUserName.isNotEmpty
                    ? widget.otherUserName[0].toUpperCase()
                    : '?',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.otherUserName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  // NEW: show member names under the group name, WhatsApp-style
                  if (widget.isGroup && groupMembersAsync != null && groupMembersAsync.hasValue)
                    Text(
                      groupMembersAsync.value!.values.join(', '),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Say hi 👋', style: TextStyle(color: Colors.grey)),
                  );
                }

                List<dynamic> sortedMessages = List.from(messages);
                sortedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

                Map<String, String> memberNames = {};
                if (groupMembersAsync != null && groupMembersAsync.hasValue) {
                  memberNames = groupMembersAsync.value!;
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: sortedMessages.length,
                  itemBuilder: (context, index) {
                    int realIndex = sortedMessages.length - 1 - index;
                    final msg = sortedMessages[realIndex];
                    final isMe = msg.senderId == _currentUserId;

                    String? senderName;
                    if (widget.isGroup && !isMe) {
                      senderName = memberNames[msg.senderId];
                    }

                    // message bubble style is untouched, only the screen
                    // around it has been polished
                    return MessageBubble(
                      key: ValueKey(msg.id),
                      text: msg.content,
                      time: msg.createdAt,
                      isMe: isMe,
                      status: msg.status,
                      senderName: senderName,
                      messageType: msg.messageType,
                      mediaUrl: msg.mediaUrl,
                      durationSeconds: msg.durationSeconds,
                      onStopLiveLocation: isMe ? () => _stopLiveLocation(msg.id) : null,
                      onLongPress: isMe ? () => _showMessageOptions(msg) : null,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
          // ---- Input bar ----
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Attach panel smoothly grows above the input bar
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: _showAttachPanel ? _buildAttachPanel() : const SizedBox(width: double.infinity),
                ),

                // Input row + lock hint bubble
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: double.infinity,
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: recorder.isRecording
                                ? _buildRecordingBar(recorder)
                                : _buildTypingBar(),
                          ),
                          const SizedBox(width: 8),
                          _buildRightButton(recorder),
                        ],
                      ),
                    ),

                    // Lock hint floats above the mic while holding
                    if (recorder.isRecording && !recorder.isLocked)
                      Positioned(right: 10, bottom: 66, child: _buildLockHint()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // Left side of the input bar while recording
  Widget _buildRecordingBar(VoiceRecorderState recorder) {
    final timerText = Text(
      _formatRecordTime(recorder.seconds),
      style: const TextStyle(
        fontSize: 15,
        color: Colors.black87,
        fontWeight: FontWeight.w500,
      ),
    );

    // Locked: trash button + timer + live waveform
    if (recorder.isLocked) {
      return SizedBox(
        height: 44,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _cancelVoiceRecording,
            ),
            timerText,
            const SizedBox(width: 12),
            Expanded(child: LiveWaveform(levels: recorder.levels)),
          ],
        ),
      );
    }

    // Still holding: red mic + timer + "Slide to cancel"
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.mic, color: Colors.red, size: 22),
          const SizedBox(width: 8),
          timerText,
          const Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chevron_left, size: 18, color: Colors.grey),
                SizedBox(width: 2),
                Text(
                  'Slide to cancel',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Left side of the input bar for normal typing
  Widget _buildTypingBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          icon: const Icon(Icons.attach_file, color: kHeaderColor),
          onPressed: _toggleAttachPanel,
        ),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _messageController,
              minLines: 1,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Right side button: send (locked / typed text) or mic
  Widget _buildRightButton(VoiceRecorderState recorder) {
    // Locked recording: send button
    if (recorder.isRecording && recorder.isLocked) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: kAccentColor,
        child: IconButton(
          icon: const Icon(Icons.send, color: Colors.white, size: 20),
          onPressed: _stopVoiceRecording,
        ),
      );
    }

    // Text typed: normal send button
    if (!recorder.isRecording && _messageController.text.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: kAccentColor,
        child: IconButton(
          icon: const Icon(Icons.send, color: Colors.white, size: 20),
          onPressed: _sendMessage,
        ),
      );
    }

    // Otherwise: mic button with hold / lock / cancel gestures
    return VoiceMicButton(
      isRecording: recorder.isRecording,
      onStart: _startVoiceRecording,
      onLock: _lockVoiceRecording,
      onCancel: _cancelVoiceRecording,
      onSend: _stopVoiceRecording,
    );
  }

  // Small "lock" bubble shown above the mic while holding
  Widget _buildLockHint() {
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 20, color: Colors.grey),
          SizedBox(height: 4),
          Icon(Icons.keyboard_arrow_up, size: 20, color: Colors.grey),
        ],
      ),
    );
  }
}
