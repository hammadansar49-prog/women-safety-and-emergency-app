import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'call_controller.dart';
import 'chat_screen.dart';
import 'social_controller.dart';
import 'theme/tokens.dart';
import 'ui/design.dart';

/// What a buddy sees when someone they protect sends an SOS: who, how long
/// ago, where they last were, and a one-tap way to call the emergency number.
/// SafeHer never dials for you; the call button only opens the dialer.
class IncomingSosScreen extends StatefulWidget {
  const IncomingSosScreen({
    super.key,
    required this.social,
    required this.eventId,
    this.calls,
  });

  final SocialController social;
  final String eventId;

  /// Opens the sender's live camera and microphone, when they are sharing.
  final CallController? calls;

  @override
  State<IncomingSosScreen> createState() => _IncomingSosScreenState();
}

class _IncomingSosScreenState extends State<IncomingSosScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ping = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(
      const Duration(seconds: 1),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _ping.dispose();
    _tick?.cancel();
    super.dispose();
  }

  String _ago(DateTime since) {
    final d = DateTime.now().difference(since);
    if (d.inSeconds < 60) return '${d.inSeconds < 0 ? 0 : d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    return '${d.inHours} h ago';
  }

  Future<void> _call() async {
    final ok = await launchUrl(Uri(scheme: 'tel', path: '15'));
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the phone dialer.')),
      );
    }
  }

  /// Opens the sender's live camera, and says so when it cannot be reached
  /// instead of leaving the button looking broken.
  Future<void> _watch(String streamId) async {
    await widget.calls!.watchSos(streamId);
    final problem = widget.calls!.error;
    if (problem != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(problem)));
    }
  }

  Future<void> _openMap(double lat, double lng) => launchUrl(
    Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
    mode: LaunchMode.externalApplication,
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.social,
    builder: (context, _) {
      final event = widget.social.visibleEvents
          .where((e) => e.id == widget.eventId)
          .firstOrNull;
      final theme = Theme.of(context);
      if (event == null) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Text('This alert is no longer available.',
                style: theme.textTheme.bodyLarge),
          ),
        );
      }
      final sender = widget.social.person(event.senderId);
      final active = event.status == LocalSosStatus.active;
      final hasPoint = event.lastLat != null && event.lastLng != null;
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: HeaderPage(
          headerHeight: 330,
          overlap: 30,
          bottomPadding: 40,
          animate: false,
          header: Column(
            children: [
              Row(
                children: [
                  HeaderBack(onTap: () => Navigator.of(context).maybePop()),
                  const Spacer(),
                  _StatusPill(active: active),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 118,
                height: 118,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (active)
                      AnimatedBuilder(
                        animation: _ping,
                        builder: (context, _) => Container(
                          width: 72 + 46 * _ping.value,
                          height: 72 + 46 * _ping.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(
                              alpha: 0.28 * (1 - _ping.value),
                            ),
                          ),
                        ),
                      ),
                    AvatarDot(name: sender.name, size: 72),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                active
                    ? '${sender.name} needs help'
                    : '${sender.name} ended the SOS',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Started ${_ago(event.createdAt)}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const IconChip(Icons.location_on_outlined),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          active ? 'Last known location' : 'Ended here',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasPoint
                              ? '${event.lastLat!.toStringAsFixed(5)}, ${event.lastLng!.toStringAsFixed(5)}'
                              : 'Location unavailable. Waiting for a connection.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (hasPoint)
                    PillButton(
                      label: 'Map',
                      onTap: () => _openMap(event.lastLat!, event.lastLng!),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (active && widget.calls != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: BerryButton(
                  label: 'Watch live camera',
                  icon: Icons.videocam_rounded,
                  // On this side the event id is already the sender's event
                  // plus this account, which is exactly the live stream's id.
                  onTap: () => _watch(event.id),
                ),
              ),
            BerryButton(label: 'Call 15', onTap: _call),
            const SizedBox(height: 10),
            OutlinedPill(
              label: 'Message ${sender.name}',
              onTap: () => Navigator.of(context).push(
                SafeRoute<void>(
                  builder: (_) =>
                      ChatScreen(social: widget.social, friendId: sender.id),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'SafeHer only opens your phone dialer. You choose whether to call.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    },
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(99),
      color: active
          ? AppColors.primary
          : (AppColors.light ? Colors.white : AppColors.surface),
    ),
    child: Text(
      active ? 'LIVE' : 'ENDED',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        color: active ? Colors.white : AppColors.textMuted,
      ),
    ),
  );
}
