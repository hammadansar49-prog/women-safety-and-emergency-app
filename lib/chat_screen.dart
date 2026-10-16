import 'package:flutter/material.dart';
import 'social_controller.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.social,
    required this.friendId,
    this.safetyBannerBuilder,
  });

  final SocialController social;
  final String friendId;
  final WidgetBuilder? safetyBannerBuilder;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  late final String _ownerId = widget.social.currentUserId;

  bool get _available =>
      widget.social.currentUserId == _ownerId &&
      widget.social.areFriends(_ownerId, widget.friendId);

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    if (!_available) return;
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    try {
      widget.social.sendMessage(widget.friendId, text);
      _composer.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Message could not be sent. Check your friendship and keep messages under 2,001 characters.',
          ),
        ),
      );
    }
  }

  void _call(bool video) {
    if (!_available) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _CallPreview(
          name: widget.social.person(widget.friendId).name,
          video: video,
          safetyBannerBuilder: widget.safetyBannerBuilder,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.social,
    builder: (context, _) {
      final friend = widget.social.person(widget.friendId);
      final available = _available;
      final messages = available
          ? widget.social.messagesWith(widget.friendId)
          : <ChatMessage>[];
      final colors = Theme.of(context).colorScheme;
      return Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(friend.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                '@${friend.username}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Audio call',
              onPressed: available ? () => _call(false) : null,
              icon: const Icon(Icons.call_outlined),
            ),
            IconButton(
              tooltip: 'Video call',
              onPressed: available ? () => _call(true) : null,
              icon: const Icon(Icons.videocam_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                children: [
                  if (widget.safetyBannerBuilder != null)
                    widget.safetyBannerBuilder!(context),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: colors.secondaryContainer,
                    child: const Text(
                      'Local preview • messages stay in this session',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: !available
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'This conversation is unavailable. Return to Contacts to open a chat for your current profile.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : messages.isEmpty
                        ? const Center(
                            child: Text(
                              'Say hello to start your conversation.',
                            ),
                          )
                        : ListView.builder(
                            controller: _scroll,
                            reverse: true,
                            padding: const EdgeInsets.all(16),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message =
                                  messages[messages.length - index - 1];
                              final mine = message.senderId == _ownerId;
                              return Align(
                                alignment: mine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: .85,
                                  child: Align(
                                    alignment: mine
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: mine
                                            ? colors.primaryContainer
                                            : colors.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            message.text,
                                            style: TextStyle(
                                              color: mine
                                                  ? colors.onPrimaryContainer
                                                  : colors.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            MaterialLocalizations.of(
                                              context,
                                            ).formatTimeOfDay(
                                              TimeOfDay.fromDateTime(
                                                message.createdAt.toLocal(),
                                              ),
                                            ),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.labelSmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _composer,
                            enabled: available,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: 2000,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: const InputDecoration(
                              hintText: 'Write a message',
                              border: OutlineInputBorder(),
                              counterText: '',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: 'Send message',
                          onPressed: available ? _send : null,
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _CallPreview extends StatelessWidget {
  const _CallPreview({
    required this.name,
    required this.video,
    this.safetyBannerBuilder,
  });
  final String name;
  final bool video;
  final WidgetBuilder? safetyBannerBuilder;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(video ? 'Video call preview' : 'Audio call preview'),
    ),
    body: SafeArea(
      child: Column(
        children: [
          if (safetyBannerBuilder != null) safetyBannerBuilder!(context),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        video
                            ? Icons.videocam_off_outlined
                            : Icons.mic_off_outlined,
                        size: 72,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        name,
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Call preview — no live connection',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Live calls will be connected in the Firebase/WebRTC phase. Camera and microphone are not active.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.call_end),
                        label: const Text('End call preview'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
