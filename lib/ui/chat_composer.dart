import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../voice_recorder.dart';
import 'motion.dart';

/// The row along the bottom of a conversation: attachments, the text field,
/// the camera, and hold-to-talk.
///
/// Holding the microphone records; sliding up locks it so the person can let
/// go and keep talking, which matters when one hand is busy. Letting go
/// without locking sends; sliding away cancels.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onSend,
    required this.onVoice,
    this.onAttach,
    this.onCamera,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;
  final void Function(Uint8List audio, int seconds) onVoice;
  final VoidCallback? onAttach;
  final VoidCallback? onCamera;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _voice = VoiceRecorder();
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTyping);
    _voice.addListener(_onVoiceChanged);
  }

  void _onTyping() => setState(() {});
  void _onVoiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTyping);
    _voice.removeListener(_onVoiceChanged);
    _voice.dispose();
    super.dispose();
  }

  bool get _hasText => widget.controller.text.trim().isNotEmpty;

  Future<void> _startVoice() async {
    if (!widget.enabled) return;
    final ok = await _voice.start();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('SafeHer needs the microphone to record a note.'),
          ),
        );
    }
  }

  Future<void> _finishVoice() async {
    final note = await _voice.stopAndRead();
    if (note == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Hold the microphone to record.')),
          );
      }
      return;
    }
    widget.onVoice(note.bytes, note.seconds);
  }

  @override
  Widget build(BuildContext context) {
    if (_voice.recording) return _recordingBar();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _circle(
          icon: Icons.add_rounded,
          label: 'Add an attachment',
          onTap: widget.enabled ? widget.onAttach : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: widget.controller,
            enabled: widget.enabled,
            minLines: 1,
            maxLines: 5,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => widget.onSend(),
            decoration: InputDecoration(
              hintText: 'Message',
              counterText: '',
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              border: _pill(AppColors.border),
              enabledBorder: _pill(AppColors.border),
              focusedBorder: _pill(AppColors.primary, 1.6),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (_hasText)
          _circle(
            icon: Icons.send_rounded,
            label: 'Send message',
            filled: true,
            onTap: widget.enabled ? widget.onSend : null,
          )
        else ...[
          _circle(
            icon: Icons.photo_camera_rounded,
            label: 'Camera',
            onTap: widget.enabled ? widget.onCamera : null,
          ),
          const SizedBox(width: 8),
          // Hold to record; slide up to keep it going hands-free.
          GestureDetector(
            onLongPressStart: (_) => _startVoice(),
            onLongPressMoveUpdate: (d) {
              if (!_voice.recording) return;
              if (d.localOffsetFromOrigin.dy < -56) _voice.lock();
              final away = d.localOffsetFromOrigin.dx < -90;
              if (away != _cancelling) setState(() => _cancelling = away);
            },
            onLongPressEnd: (_) {
              if (!_voice.recording || _voice.locked) return;
              if (_cancelling) {
                setState(() => _cancelling = false);
                _voice.cancel();
              } else {
                _finishVoice();
              }
            },
            child: _circle(
              icon: Icons.mic_rounded,
              label: 'Hold to record a voice note',
              filled: true,
              onTap: widget.enabled
                  ? () {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Hold to record. Slide up to keep recording '
                              'without holding.',
                            ),
                          ),
                        );
                    }
                  : null,
            ),
          ),
        ],
      ],
    );
  }

  /// What the composer turns into while a note is being recorded.
  Widget _recordingBar() {
    final mins = _voice.elapsed.inMinutes.toString().padLeft(2, '0');
    final secs = (_voice.elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _RecordingDot(),
              const SizedBox(width: 10),
              Text(
                '$mins:$secs',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: CustomPaint(
                    painter: _Waveform(
                      levels: _voice.levels,
                      color: _cancelling ? AppColors.danger : AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (!_voice.locked)
            Text(
              _cancelling
                  ? 'Release to cancel'
                  : 'Slide up to keep recording without holding',
              style: TextStyle(
                fontSize: 12,
                color: _cancelling ? AppColors.danger : AppColors.textMuted,
              ),
            ),
          // Always offered, never only while the finger is down: a touch that
          // slips must not leave someone stuck recording.
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => _voice.cancel(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: _finishVoice,
                  child: Text(
                    'Send',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _pill(Color colour, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: colour, width: width),
      );

  Widget _circle({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool filled = false,
  }) => Pressable(
    borderRadius: BorderRadius.circular(999),
    onTap: onTap,
    semanticLabel: label,
    child: Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Container(
        width: 50,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? AppColors.primary : AppColors.surface,
          border: Border.all(
            color: filled ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Icon(
          icon,
          size: 22,
          color: filled ? AppColors.onPrimary : AppColors.text,
        ),
      ),
    ),
  );
}

/// The pulsing red dot that says a microphone is live.
class _RecordingDot extends StatefulWidget {
  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
    child: Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.danger,
      ),
    ),
  );
}

/// Bars drawn from the real microphone levels, newest on the right.
class _Waveform extends CustomPainter {
  const _Waveform({required this.levels, required this.color});
  final List<double> levels;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    const gap = 5.0;
    final count = math.min(levels.length, (size.width / gap).floor());
    for (var i = 0; i < count; i++) {
      final level = levels[levels.length - count + i];
      final h = math.max(3.0, level * size.height);
      final x = size.width - (count - i) * gap + gap / 2;
      canvas.drawLine(
        Offset(x, size.height / 2 - h / 2),
        Offset(x, size.height / 2 + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Waveform old) => true;
}
