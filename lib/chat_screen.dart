import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'package:flutter/material.dart';

import 'call_controller.dart';
import 'call_signaling.dart';
import 'incoming_sos_screen.dart';
import 'social_controller.dart';
import 'theme/tokens.dart';
import 'ui/chat_composer.dart';
import 'ui/design.dart';
import 'ui/motion.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.social,
    required this.friendId,
    this.calls,
    this.safetyBannerBuilder,
  });

  final SocialController social;

  /// Lets this chat place a real call. Null in tests and in local mode.
  final CallController? calls;
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
  void initState() {
    super.initState();
    // Lets the other side see that this conversation is being read.
    widget.social.enterChat(widget.friendId);
  }

  @override
  void dispose() {
    widget.social.leaveChat();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    });
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

  void _sendVoice(Uint8List audio, int seconds) {
    if (!_available) return;
    try {
      widget.social.sendVoice(widget.friendId, audio, seconds);
      _scrollToEnd();
    } on StateError catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// What the "+" offers. Only what SafeHer can actually deliver appears
  /// here; the rest would be a button that does nothing in an emergency.
  void _openAttachments() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const IconChip(Icons.photo_camera_rounded),
              title: const Text('Camera'),
              subtitle: const Text('Take a photo and send it'),
              onTap: () {
                Navigator.of(sheet).pop();
                _takePhoto();
              },
            ),
            ListTile(
              leading: const IconChip(Icons.photo_library_rounded),
              title: const Text('Photos'),
              subtitle: const Text('Pick one from this phone'),
              onTap: () {
                Navigator.of(sheet).pop();
                _pickPhoto();
              },
            ),
            ListTile(
              leading: const IconChip(Icons.place_rounded),
              title: const Text('My location'),
              subtitle: const Text('Send where you are right now'),
              onTap: () {
                Navigator.of(sheet).pop();
                _shareLocation();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _notYet(String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$what is not ready yet.')));
  }

  void _takePhoto() => _notYet('Sending photos');
  void _pickPhoto() => _notYet('Sending photos');
  void _shareLocation() => _notYet('Sharing your location in chat');

  void _call(bool video) {
    if (!_available) return;
    final calls = widget.calls;
    if (calls != null && widget.social.cloudConnected) {
      if (calls.inCall) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('You are already in a call.')),
          );
        return;
      }
      calls.call(widget.friendId, video ? CallKind.video : CallKind.audio);
      return;
    }
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
                        Builder(
                          builder: (context) {
                            final here = widget.social.presenceOf(friend.id);
                            // Reading this very chat gets the live dot; online
                            // elsewhere, or a last seen, is just the line.
                            final reading = here.readingWith(_ownerId);
                            final status = here.label.isEmpty
                                ? (sos ? 'SOS buddy' : 'Buddy')
                                : here.label;
                            return Row(
                              children: [
                                AnimatedContainer(
                                  duration: Motion.standard,
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: here.online
                                        ? AppColors.success
                                        : AppColors.textMuted,
                                    boxShadow: reading
                                        ? [
                                            BoxShadow(
                                              color: AppColors.success,
                                              blurRadius: 6,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    status,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 12,
                                      color: here.online
                                          ? AppColors.success
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  if (available) ...[
                    // Calling is the thing you reach for in a hurry, so it sits
                    // in the header rather than two taps down a menu.
                    _roundIcon(
                      Icons.call_rounded,
                      AppColors.text,
                      'Voice call',
                      () => _call(false),
                    ),
                    const SizedBox(width: 6),
                    _roundIcon(
                      Icons.videocam_rounded,
                      AppColors.text,
                      'Video call',
                      () => _call(true),
                    ),
                    const SizedBox(width: 6),
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
                          widget.social.cloudConnected
                              ? 'End-to-end encrypted · only you two can read this'
                              : 'Not connected · messages stay on this device',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                          ),
                        ),
                      ),
                      // A buddy in trouble is reachable from the chat you are
                      // already in, not only from the banner on Home.
                      Builder(
                        builder: (context) {
                          final live = widget.social.visibleEvents
                              .where(
                                (e) =>
                                    e.senderId == widget.friendId &&
                                    e.status == LocalSosStatus.active,
                              )
                              .toList();
                          if (live.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: BerryButton(
                              label: 'See ${friend.name}’s SOS',
                              icon: Icons.sos_rounded,
                              onTap: () => Navigator.of(context).push(
                                SafeRoute<void>(
                                  builder: (_) => IncomingSosScreen(
                                    social: widget.social,
                                    eventId: live.first.id,
                                    calls: widget.calls,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
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
                                  final at = messages.length - index - 1;
                                  final message = messages[at];
                                  final day = message.createdAt.toLocal();
                                  final newDay =
                                      at == 0 ||
                                      !_sameDay(
                                        messages[at - 1].createdAt.toLocal(),
                                        day,
                                      );
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (newDay) _DayLabel(day),
                                      if (at == 0 && sos)
                                        _SosChip(
                                          '${friend.name} is now one of your SOS buddies',
                                        ),
                                      if (message.isVoice)
                                        _VoiceBubble(
                                          message: message,
                                          mine: message.senderId == _ownerId,
                                          status: message.senderId == _ownerId
                                              ? widget.social.statusOf(
                                                  message.id,
                                                )
                                              : null,
                                        )
                                      else if (message.isCall)
                                        _MissedCallRow(
                                          message: message,
                                          mine: message.senderId == _ownerId,
                                        )
                                      else
                                        _Bubble(
                                          message: message,
                                          mine: message.senderId == _ownerId,
                                          status: message.senderId == _ownerId
                                              ? widget.social.statusOf(
                                                  message.id,
                                                )
                                              : null,
                                        ),
                                    ],
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
                        child: ChatComposer(
                          controller: _composer,
                          enabled: available,
                          onSend: _send,
                          onVoice: _sendVoice,
                          onAttach: _openAttachments,
                          onCamera: _takePhoto,
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

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "Today", "Yesterday" or the date, centred above that day's messages.
class _DayLabel extends StatelessWidget {
  const _DayLabel(this.day);
  final DateTime day;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String get _text {
    final now = DateTime.now();
    if (_sameDay(day, now)) return 'Today';
    if (_sameDay(day, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return '${day.day} ${_months[day.month - 1]} ${day.year}';
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 12),
    child: Center(
      child: Text(
        _text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

/// A small system note in the thread, such as a buddy being added.
class _SosChip extends StatelessWidget {
  const _SosChip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: AppColors.tint,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: 14, color: AppColors.accent),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.light ? AppColors.onHeader : null,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A call nobody answered, shown the way a phone's call log shows one: a quiet
/// centred line rather than a message from either side.
class _MissedCallRow extends StatelessWidget {
  const _MissedCallRow({required this.message, required this.mine});
  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final video = message.kind == MessageKind.missedVideoCall;
    final t = message.createdAt.toLocal();
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final clock =
        '$hour:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.tint,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                video ? Icons.videocam_off_rounded : Icons.phone_missed_rounded,
                size: 16,
                color: AppColors.danger,
              ),
              const SizedBox(width: 8),
              Text(
                mine
                    ? 'No answer · ${video ? 'video' : 'voice'} call'
                    : 'Missed ${video ? 'video' : 'voice'} call',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                clock,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A voice note: play, a bar that fills as it plays, and its length.
class _VoiceBubble extends StatefulWidget {
  const _VoiceBubble({required this.message, required this.mine, this.status});
  final ChatMessage message;
  final bool mine;
  final MessageStatus? status;

  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  final _player = AudioPlayer();
  bool _playing = false;
  Duration _at = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _at = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _at = Duration.zero);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final audio = widget.message.audio;
    if (audio == null) return;
    if (_playing) {
      await _player.pause();
      return;
    }
    await _player.play(BytesSource(audio));
  }

  @override
  Widget build(BuildContext context) {
    final mine = widget.mine;
    final fg = mine ? Colors.white : AppColors.text;
    final total = widget.message.seconds;
    final progress = total == 0
        ? 0.0
        : (_at.inMilliseconds / (total * 1000)).clamp(0.0, 1.0);
    final left = total - _at.inSeconds;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
        constraints: const BoxConstraints(maxWidth: 300),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Pressable(
              borderRadius: BorderRadius.circular(999),
              onTap: _toggle,
              semanticLabel: _playing ? 'Pause' : 'Play voice note',
              child: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mine
                      ? Colors.white.withValues(alpha: 0.22)
                      : AppColors.tint,
                ),
                child: Icon(
                  _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: fg,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 120,
              height: 26,
              child: CustomPaint(
                painter: _PlayedBars(
                  progress: progress,
                  played: fg,
                  rest: fg.withValues(alpha: 0.35),
                  seed: widget.message.id.hashCode,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '0:${(_at.inSeconds > 0 ? left : total).clamp(0, 99).toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (mine && widget.status != null) ...[
                  const SizedBox(height: 2),
                  _Ticks(status: widget.status!),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Fixed bars that fill as the note plays. They are drawn from the message id
/// so each note keeps its own shape, rather than pretending to be the real
/// waveform of audio that has not been decoded yet.
class _PlayedBars extends CustomPainter {
  const _PlayedBars({
    required this.progress,
    required this.played,
    required this.rest,
    required this.seed,
  });
  final double progress;
  final Color played;
  final Color rest;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    const gap = 5.0;
    final count = (size.width / gap).floor();
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    for (var i = 0; i < count; i++) {
      final h = size.height * (0.25 + rng.nextDouble() * 0.75);
      paint.color = i / count <= progress ? played : rest;
      final x = i * gap + gap / 2;
      canvas.drawLine(
        Offset(x, size.height / 2 - h / 2),
        Offset(x, size.height / 2 + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PlayedBars old) => old.progress != progress;
}

/// One tick while it is on its way, two once their device has it, two in blue
/// once they have opened the conversation.
class _Ticks extends StatelessWidget {
  const _Ticks({required this.status});
  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    final read = status == MessageStatus.read;
    final colour = read ? const Color(0xFF6FD3FF) : Colors.white70;
    final label = switch (status) {
      MessageStatus.sent => 'Sent',
      MessageStatus.delivered => 'Delivered',
      MessageStatus.read => 'Read',
    };
    return Semantics(
      label: label,
      child: Icon(
        status == MessageStatus.sent
            ? Icons.check_rounded
            : Icons.done_all_rounded,
        size: 15,
        color: colour,
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine, this.status});
  final ChatMessage message;
  final bool mine;

  /// Only set for your own messages; null for theirs.
  final MessageStatus? status;

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
            // Wrap hugs short messages and drops the time to its own line
            // only when the text fills the row, as in WhatsApp.
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 10,
              children: [
                Text(
                  message.text,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: fg,
                    fontSize: 14.5,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      MaterialLocalizations.of(context).formatTimeOfDay(
                        TimeOfDay.fromDateTime(message.createdAt.toLocal()),
                      ),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: fg.withValues(alpha: 0.7),
                      ),
                    ),
                    if (mine && status != null) ...[
                      const SizedBox(width: 4),
                      _Ticks(status: status!),
                    ],
                  ],
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
