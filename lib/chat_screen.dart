import 'package:flutter/material.dart';

import 'social_controller.dart';
import 'theme/tokens.dart';
import 'ui/design.dart';
import 'ui/motion.dart';

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
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
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

  /// Connects or disconnects this buddy from SOS. Up to five buddies can be
  /// connected at once; an SOS goes to every connected buddy who approved it.
  void _toggleSosBuddy() {
    final social = widget.social;
    final id = widget.friendId;
    final name = social.person(id).name;
    String message;
    try {
      if (social.isFavorite(id)) {
        social.unfavorite(id);
        message = '$name removed from your SOS buddies';
      } else {
        social.favorite(id);
        message = social.isApprovedFavorite(id)
            ? '$name added to your SOS buddies'
            : 'Request sent. $name must approve before receiving your SOS.';
      }
    } on StateError catch (e) {
      message = e.message;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _call(bool video) {
    if (!_available) return;
    Navigator.of(context).push(
      SafeRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _CallScreen(
          name: widget.social.person(widget.friendId).name,
          video: video,
          safetyBannerBuilder: widget.safetyBannerBuilder,
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      SafeRoute<void>(
        builder: (_) => ChatSettingsScreen(
          social: widget.social,
          friendId: widget.friendId,
          onToggleSos: _toggleSosBuddy,
          onCall: _call,
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
      final sos = widget.social.isFavorite(widget.friendId);
      final messages = available
          ? widget.social.messagesWith(widget.friendId)
          : <ChatMessage>[];
      final theme = Theme.of(context);
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            if (widget.safetyBannerBuilder != null)
              widget.safetyBannerBuilder!(context),
            BlushHeader(
              height: 116,
              bottomRadius: 32,
              child: Row(
                children: [
                  const SizedBox(width: 0),
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    behavior: HitTestBehavior.opaque,
                    child: Semantics(
                      button: true,
                      label: 'Back',
                      child: SizedBox(
                        width: 36,
                        height: 44,
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ),
                  AvatarDot(name: friend.name, size: 42),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@${friend.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        Row(
                          children: [
                            AnimatedContainer(
                              duration: Motion.standard,
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: sos
                                    ? AppColors.success
                                    : AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              sos ? 'SOS buddy' : 'Buddy',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (available) ...[
                    _roundIcon(
                      sos ? Icons.star_rounded : Icons.star_border_rounded,
                      sos ? AppColors.primary : AppColors.text,
                      'SOS buddy',
                      _toggleSosBuddy,
                    ),
                    const SizedBox(width: 6),
                    _MenuButton(
                      sos: sos,
                      onToggleSos: _toggleSosBuddy,
                      onSettings: _openSettings,
                      onCall: _call,
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: AppColors.tint,
                        ),
                        child: Text(
                          'Not connected · messages stay on this device',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: !available
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                    'This conversation is unavailable. Return to Buddies to open a chat for your current profile.',
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
                                  return _Bubble(
                                    message: message,
                                    mine: message.senderId == _ownerId,
                                  );
                                },
                              ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          16 + MediaQuery.of(context).padding.bottom,
                        ),
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
                                textCapitalization:
                                    TextCapitalization.sentences,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _send(),
                                decoration: InputDecoration(
                                  hintText: 'Message',
                                  counterText: '',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(999),
                                    borderSide: BorderSide(
                                      color: AppColors.border,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(999),
                                    borderSide: BorderSide(
                                      color: AppColors.border,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(999),
                                    borderSide: BorderSide(
                                      color: AppColors.primary,
                                      width: 1.6,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Pressable(
                              borderRadius: BorderRadius.circular(999),
                              onTap: available ? _send : null,
                              semanticLabel: 'Send message',
                              child: Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary,
                                ),
                                child: const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _roundIcon(
    IconData icon,
    Color color,
    String label,
    VoidCallback onTap,
  ) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.standard,
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.light ? AppColors.surface : AppColors.tint,
        ),
        child: AnimatedSwitcher(
          duration: Motion.standard,
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Icon(icon, key: ValueKey(icon), color: color, size: 22),
        ),
      ),
    ),
  );
}

/// The three-dot menu: a popup that scales in from its corner.
class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.sos,
    required this.onToggleSos,
    required this.onSettings,
    required this.onCall,
  });
  final bool sos;
  final VoidCallback onToggleSos;
  final VoidCallback onSettings;
  final void Function(bool video) onCall;

  PopupMenuItem<String> _item(String value, IconData icon, String label) =>
      PopupMenuItem<String>(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'More',
    padding: EdgeInsets.zero,
    offset: const Offset(0, 48),
    popUpAnimationStyle: const AnimationStyle(
      curve: Curves.easeOutBack,
      duration: Duration(milliseconds: 320),
      reverseDuration: Duration(milliseconds: 160),
    ),
    icon: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.light ? AppColors.surface : AppColors.tint,
      ),
      child: Icon(Icons.more_vert_rounded, color: AppColors.text, size: 20),
    ),
    onSelected: (value) {
      switch (value) {
        case 'sos':
          onToggleSos();
        case 'settings':
          onSettings();
        case 'audio':
          onCall(false);
        case 'video':
          onCall(true);
      }
    },
    itemBuilder: (_) => [
      _item(
        'sos',
        sos ? Icons.star_rounded : Icons.star_border_rounded,
        sos ? 'Remove from SOS buddies' : 'Add to SOS buddies',
      ),
      _item('settings', Icons.tune_rounded, 'Chat settings'),
      _item('audio', Icons.call_outlined, 'Voice call'),
      _item('video', Icons.videocam_outlined, 'Video call'),
    ],
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});
  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = mine ? Colors.white : AppColors.text;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduceMotionOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset((mine ? 14 : -14) * (1 - t), 0),
          child: child,
        ),
      ),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(15, 11, 15, 8),
            decoration: BoxDecoration(
              color: mine ? AppColors.primary : AppColors.surface,
              border: mine ? null : Border.all(color: AppColors.border),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(mine ? 20 : 6),
                bottomRight: Radius.circular(mine ? 6 : 20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    message.text,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: fg,
                      fontSize: 14.5,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  MaterialLocalizations.of(context).formatTimeOfDay(
                    TimeOfDay.fromDateTime(message.createdAt.toLocal()),
                  ),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: fg.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Per-chat settings: SOS buddy switch, calls, removing the buddy.
class ChatSettingsScreen extends StatelessWidget {
  const ChatSettingsScreen({
    super.key,
    required this.social,
    required this.friendId,
    required this.onToggleSos,
    required this.onCall,
  });

  final SocialController social;
  final String friendId;
  final VoidCallback onToggleSos;
  final void Function(bool video) onCall;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: ListenableBuilder(
      listenable: social,
      builder: (context, _) {
        final friend = social.person(friendId);
        final sos = social.isFavorite(friendId);
        final approved = social.isApprovedFavorite(friendId);
        return HeaderPage(
          headerHeight: 250,
          overlap: -18,
          bottomPadding: 40,
          header: Column(
            children: [
              const HeaderBack(),
              AvatarDot(name: friend.name, size: 78),
              const SizedBox(height: 8),
              Text(
                '@${friend.username}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          children: [
            const SectionLabel('SOS'),
            RowCard(
              leading: Icon(
                Icons.star_rounded,
                color: AppColors.primary,
                size: 28,
              ),
              title: 'SOS buddy',
              detail: sos
                  ? (approved
                        ? 'Approved · receives your SOS'
                        : 'Waiting for their approval')
                  : 'Not receiving your SOS',
              trailing: SoftSwitch(
                value: sos,
                label: 'SOS buddy',
                onChanged: (_) => onToggleSos(),
              ),
            ),
            const SectionLabel('Chat'),
            RowCard(
              leading: const IconChip(Icons.call_outlined),
              title: 'Voice call',
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
              onTap: () => onCall(false),
            ),
            RowCard(
              leading: const IconChip(Icons.videocam_outlined),
              title: 'Video call',
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
              onTap: () => onCall(true),
            ),
            const SectionLabel('Privacy'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: AppColors.tint,
              ),
              child: Text(
                '${friend.name} never sees your location, camera or microphone unless you start an SOS and they have accepted.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 12),
            RowCard(
              leading: const IconChip(Icons.person_remove_outlined),
              title: 'Remove buddy',
              onTap: () {
                try {
                  social.removeFriend(friendId);
                  Navigator.of(context)
                    ..pop()
                    ..pop();
                } on StateError catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(e.message)));
                }
              },
            ),
          ],
        );
      },
    ),
  );
}

class _CallScreen extends StatefulWidget {
  const _CallScreen({
    required this.name,
    required this.video,
    this.safetyBannerBuilder,
  });
  final String name;
  final bool video;
  final WidgetBuilder? safetyBannerBuilder;

  @override
  State<_CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<_CallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ping = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _ping.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.header,
      body: SafeArea(
        child: Column(
          children: [
            if (widget.safetyBannerBuilder != null)
              widget.safetyBannerBuilder!(context),
            const SizedBox(height: 28),
            Text(
              widget.video ? 'Video call' : 'Voice call',
              style: theme.textTheme.bodyMedium,
            ),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 280,
                  height: 280,
                  child: AnimatedBuilder(
                    animation: _ping,
                    builder: (context, _) => Stack(
                      alignment: Alignment.center,
                      children: [
                        for (final shift in const [0.0, 0.5])
                          Builder(
                            builder: (_) {
                              final v = (_ping.value + shift) % 1.0;
                              return Opacity(
                                opacity: (0.6 * (1 - v)).clamp(0.0, 1.0),
                                child: Container(
                                  width: 200 * (0.9 + 0.7 * v),
                                  height: 200 * (0.9 + 0.7 * v),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        Container(
                          width: 190,
                          height: 190,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.orbPeach.withValues(alpha: 0.7),
                          ),
                        ),
                        AvatarDot(name: widget.name, size: 150),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Text(widget.name, style: theme.textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text('Unable to connect', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Calling is unavailable. Camera and microphone are off.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 28),
            Pressable(
              borderRadius: BorderRadius.circular(999),
              onTap: () => Navigator.of(context).pop(),
              semanticLabel: 'End call',
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
                child: const Icon(Icons.call_end_rounded, color: Colors.white),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
