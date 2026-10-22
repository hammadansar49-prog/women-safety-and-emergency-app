import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'alert_sounder.dart';
import 'call_controller.dart';
import 'call_signaling.dart';
import 'rtc_session.dart';
import 'social_controller.dart';
import 'theme/tokens.dart';
import 'ui/motion.dart';

/// Sits above the whole app: a ringing call, or the call / live view in
/// progress. Draws nothing when there is neither.
class CallOverlay extends StatelessWidget {
  const CallOverlay({super.key, required this.calls, required this.social});
  final CallController calls;
  final SocialController social;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: calls,
    builder: (context, _) {
      final session = calls.active;
      if (session != null) {
        return ActiveCallScreen(
          key: ValueKey(session.callId),
          session: session,
          social: social,
          onEnd: calls.endCall,
        );
      }
      if (calls.ringing.isNotEmpty) {
        final doc = calls.ringing.first;
        return IncomingCallScreen(
          key: ValueKey(doc.id),
          doc: doc,
          name: social.person(doc.caller).name,
          username: doc.caller,
          onAccept: () => calls.accept(doc),
          onDecline: () => calls.decline(doc),
        );
      }
      return const SizedBox.shrink();
    },
  );
}

/// The pale halo the avatar sits inside, from the locked design.
Color get _halo =>
    AppColors.light ? const Color(0xFFFFEDE5) : const Color(0xFF221D33);

/// The blush call canvas: the page colour, its two drifting orbs, and the
/// content laid over them. Every call screen is built on this.
class _CallCanvas extends StatelessWidget {
  const _CallCanvas({required this.build_});
  final Widget Function(double scale) build_;

  /// The design is drawn for a tall phone. On anything shorter the avatar
  /// badge shrinks rather than pushing the controls off the bottom.
  static double scaleFor(double height) =>
      (height / 844).clamp(0.62, 1.0).toDouble();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.header,
    body: Stack(
      children: [
        Positioned(
          right: -70,
          top: -40,
          child: _Orb(size: 220, color: AppColors.orbPeach, opacity: 0.7),
        ),
        Positioned(
          right: 50,
          bottom: 110,
          child: _Orb(size: 70, color: AppColors.orbLavender, opacity: 0.8),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => build_(scaleFor(box.maxHeight)),
          ),
        ),
      ],
    ),
  );
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color, required this.opacity});
  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: opacity,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    ),
  );
}

/// The avatar inside its halo, with two rings pinging outward while the call
/// is still being set up. The rings stop once there is someone on the line.
class _CallAvatar extends StatefulWidget {
  const _CallAvatar({
    required this.letter,
    required this.pinging,
    this.scale = 1,
  });
  final String letter;
  final bool pinging;

  /// Shrinks the whole badge on a short screen, so nothing is pushed off.
  final double scale;

  @override
  State<_CallAvatar> createState() => _CallAvatarState();
}

class _CallAvatarState extends State<_CallAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pinging) _c.repeat();
  }

  @override
  void didUpdateWidget(_CallAvatar old) {
    super.didUpdateWidget(old);
    if (widget.pinging && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.pinging && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// One ring: grows from 0.9 to 1.6 of the halo while fading out.
  Widget _ring(double t) {
    final p = (t % 1.0);
    return Transform.scale(
      scale: 0.9 + 0.7 * p,
      child: Opacity(
        opacity: (0.6 * (1 - p)).clamp(0.0, 1.0),
        child: Container(
          width: 220 * widget.scale,
          height: 220 * widget.scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 260 * widget.scale,
    height: 260 * widget.scale,
    child: Stack(
      alignment: Alignment.center,
      children: [
        if (widget.pinging)
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Stack(
              alignment: Alignment.center,
              children: [_ring(_c.value), _ring(_c.value + 0.5)],
            ),
          ),
        Container(
          width: 220 * widget.scale,
          height: 220 * widget.scale,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _halo),
          child: Container(
            width: 170 * widget.scale,
            height: 170 * widget.scale,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            child: Text(
              widget.letter,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: AppColors.onPrimary,
                fontSize: 72 * widget.scale,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Name, then the line under it, in the locked sizes.
class _CallerText extends StatelessWidget {
  const _CallerText({required this.title, required this.status});
  final String title;
  final String status;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        title,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(fontSize: 34),
      ),
      const SizedBox(height: 8),
      Text(
        status,
        style: TextStyle(fontSize: 15, color: AppColors.textMuted),
      ),
    ],
  );
}

class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({
    super.key,
    required this.doc,
    required this.name,
    required this.username,
    required this.onAccept,
    required this.onDecline,
  });
  final CallDoc doc;
  final String name;
  final String username;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final _sounder = AlertSounder();

  @override
  void initState() {
    super.initState();
    _sounder.ring();
  }

  @override
  void dispose() {
    _sounder.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.doc.kind == CallKind.video;
    return _CallCanvas(
      build_: (scale) => Column(
        children: [
          const SizedBox(height: 28),
          Text(
            video ? 'Incoming video call' : 'Incoming voice call',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const Spacer(flex: 2),
          _CallAvatar(
            letter: widget.name.isEmpty
                ? '?'
                : widget.name.substring(0, 1).toUpperCase(),
            pinging: true,
            scale: scale,
          ),
          const SizedBox(height: 18),
          _CallerText(title: '@${widget.username}', status: 'Ringing…'),
          const Spacer(flex: 3),
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 0, 48, 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _RoundButton(
                  icon: Icons.call_end_rounded,
                  label: 'Decline',
                  filled: true,
                  color: AppColors.danger,
                  onTap: widget.onDecline,
                ),
                _RoundButton(
                  icon: video ? Icons.videocam_rounded : Icons.call_rounded,
                  label: 'Accept',
                  filled: true,
                  color: AppColors.success,
                  onTap: widget.onAccept,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ActiveCallScreen extends StatefulWidget {
  const ActiveCallScreen({
    super.key,
    required this.session,
    required this.social,
    required this.onEnd,
  });
  final RtcSession session;
  final SocialController social;
  final VoidCallback onEnd;

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  final _remote = RTCVideoRenderer();
  final _local = RTCVideoRenderer();
  Timer? _clock;
  DateTime? _since;
  Duration _elapsed = Duration.zero;
  bool _ready = false;
  bool _speaker = true;

  RtcSession get s => widget.session;
  bool get _watchingSos => s.kind == CallKind.sos;

  @override
  void initState() {
    super.initState();
    s.addListener(_update);
    _setup();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_since != null && mounted) {
        setState(() => _elapsed = DateTime.now().difference(_since!));
      }
    });
  }

  Future<void> _setup() async {
    await _remote.initialize();
    await _local.initialize();
    _ready = true;
    _update();
  }

  void _update() {
    if (!mounted) return;
    if (_ready) {
      _remote.srcObject = s.remote;
      _local.srcObject = s.local;
    }
    if (s.state == RtcState.connected) _since ??= DateTime.now();
    setState(() {});
  }

  /// Voice calls start at the earpiece on a phone; this flips to the speaker.
  Future<void> _toggleSpeaker() async {
    final next = !_speaker;
    setState(() => _speaker = next);
    try {
      await Helper.setSpeakerphoneOn(next);
    } catch (_) {
      // Not every platform has an earpiece to switch away from.
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    s.removeListener(_update);
    _remote.dispose();
    _local.dispose();
    super.dispose();
  }

  String get _status {
    if (s.state == RtcState.connecting) {
      return s.isCaller && !_watchingSos ? 'Calling…' : 'Connecting…';
    }
    if (s.state == RtcState.ended) return 'Ended';
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final sec = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  List<Widget> _controls() => [
    if (!_watchingSos)
      _RoundButton(
        icon: s.micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
        label: s.micOn ? 'Mute' : 'Unmute',
        onTap: () => s.setMic(!s.micOn),
      ),
    if (s.hasVideo && !_watchingSos)
      _RoundButton(
        icon: s.cameraOn
            ? Icons.videocam_rounded
            : Icons.videocam_off_rounded,
        label: 'Camera',
        onTap: () => s.setCamera(!s.cameraOn),
      ),
    if (s.hasVideo && !_watchingSos)
      _RoundButton(
        icon: Icons.cameraswitch_rounded,
        label: 'Flip',
        onTap: s.switchCamera,
      ),
    if (_watchingSos)
      _RoundButton(
        icon: Icons.cameraswitch_rounded,
        label: 'Flip their camera',
        onTap: s.requestSwitch,
      ),
    _RoundButton(
      icon: Icons.call_end_rounded,
      label: _watchingSos ? 'Close' : 'End',
      filled: true,
      onTap: widget.onEnd,
    ),
    if (!s.hasVideo && !_watchingSos)
      _RoundButton(
        icon: _speaker ? Icons.volume_up_rounded : Icons.volume_down_rounded,
        label: 'Speaker',
        onTap: _toggleSpeaker,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final person = widget.social.person(s.peer);
    final name = person.name;
    final handle = person.username.isEmpty ? name : '@${person.username}';
    final showRemoteVideo =
        s.remote != null && s.remote!.getVideoTracks().isNotEmpty;
    final showLocal = s.hasVideo && !_watchingSos && s.local != null;

    // With a picture coming in, the picture is the screen; the blush canvas
    // carries everything else.
    if (showRemoteVideo) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E1220),
        body: Stack(
          fit: StackFit.expand,
          children: [
            RTCVideoView(
              _remote,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 14),
                  Text(
                    _watchingSos ? '$name · live SOS view' : handle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _status,
                    style: const TextStyle(
                      color: Colors.white70,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                    ),
                  ),
                  const Spacer(),
                  _ControlBar(onDark: true, children: _controls()),
                ],
              ),
            ),
            if (showLocal)
              Positioned(
                right: 16,
                top: 96,
                width: 104,
                height: 148,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  // Not mirrored: this is the picture the other side receives.
                  child: RTCVideoView(
                    _local,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return _CallCanvas(
      build_: (scale) => Column(
        children: [
          const SizedBox(height: 28),
          Text(
            switch (s.kind) {
              CallKind.video => 'Video call',
              CallKind.audio => 'Voice call',
              CallKind.sos => 'Live SOS view',
            },
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const Spacer(flex: 2),
          _CallAvatar(
            letter: name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
            pinging: s.state == RtcState.connecting,
            scale: scale,
          ),
          const SizedBox(height: 18),
          _CallerText(
            title: handle,
            status: _watchingSos && s.state == RtcState.connected
                ? 'Waiting for their camera…'
                : _status,
          ),
          const Spacer(flex: 3),
          _ControlBar(children: _controls()),
        ],
      ),
    );
  }
}

/// The row of round controls along the bottom of a call.
class _ControlBar extends StatelessWidget {
  const _ControlBar({required this.children, this.onDark = false});
  final List<Widget> children;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 22,
      runSpacing: 14,
      children: children,
    ),
  );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Filled buttons are the ones that end or answer a call.
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fill = color ?? AppColors.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Pressable(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          semanticLabel: label,
          child: Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? fill : AppColors.surface,
              border: Border.all(
                color: filled ? fill : AppColors.border,
              ),
            ),
            child: Icon(
              icon,
              size: 26,
              color: filled ? AppColors.onPrimary : AppColors.text,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 78,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}
