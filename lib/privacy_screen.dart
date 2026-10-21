import 'package:flutter/material.dart';

import 'theme/tokens.dart';
import 'ui/glass.dart';
import 'ui/motion.dart';

/// A plain-language page explaining exactly what SafeHer does and does not
/// share, and who decides. Opened from "Privacy first" in Settings.
class PrivacyGuideScreen extends StatelessWidget {
  const PrivacyGuideScreen({super.key});

  static const _steps = <_Step>[
    _Step(
      Icons.people_outline,
      'Becoming buddies is just chat',
      "When you and another person accept each other's request you become "
          'buddies. That only lets you message each other. Nothing about your '
          'location, camera or microphone is shared, and no SOS is active.',
    ),
    _Step(
      Icons.star_outline_rounded,
      'You choose who gets your SOS',
      'Only buddies you add as SOS buddies (the star in their chat menu) can '
          'ever receive your SOS, up to five at once. A buddy you did not '
          'star never receives anything.',
    ),
    _Step(
      Icons.verified_user_outlined,
      'They must agree first',
      'Starring someone sends them a request. They receive your SOS only '
          'after they accept it. Until then, or if they decline, they get '
          'nothing.',
    ),
    _Step(
      Icons.lock_outline,
      'Nothing is shared until you start an SOS',
      'SafeHer does not track you in the background and does not send data '
          'to your buddies on its own. Sharing begins only when you trigger '
          'an SOS yourself, and ends when you stop it.',
    ),
    _Step(
      Icons.shield_outlined,
      'You allow every permission yourself',
      'Live location, camera and microphone each need your permission on '
          'your phone. SafeHer asks you; it never turns them on silently. If '
          'you say no, that part is simply not shared.',
    ),
    _Step(
      Icons.sos_outlined,
      'What an SOS can share',
      'During an SOS you started, your approved SOS buddies can see your '
          'live location and, if you allowed them, hear and see through your '
          'microphone and camera, so they can understand the situation and '
          'get you help.',
    ),
    _Step(
      Icons.visibility_outlined,
      'It is always visible and stoppable',
      'While sharing is on, your phone shows it. You can cancel during the '
          'countdown, and stop the SOS at any time, and sharing ends right '
          'away.',
    ),
    _Step(
      Icons.undo_rounded,
      'Change your mind any time',
      'Remove a buddy from your SOS buddies, or revoke the approval you '
          'gave someone, whenever you like. It takes effect immediately.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final side = media.size.width < 360 ? 16.0 : 24.0;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Privacy first')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: ListView(
              padding: EdgeInsets.fromLTRB(side, Space.x4, side, Space.x8),
              children: [
                EntranceFade(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: Space.x6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You are in control',
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: Space.x2),
                        Text(
                          'Making a buddy never starts an SOS and never shares '
                          'your data. Here is exactly how it works.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                for (var i = 0; i < _steps.length; i++)
                  EntranceFade(
                    index: i + 1,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: Space.x3),
                      child: GlassPanel(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(Space.x2),
                              decoration: BoxDecoration(
                                borderRadius: Radii.brSm,
                                color: AppColors.primary.withValues(
                                  alpha: 0.18,
                                ),
                                border: Border.all(
                                  color: AppColors.glassHairline,
                                ),
                              ),
                              child: Icon(
                                _steps[i].icon,
                                color: AppColors.accent,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: Space.x4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${i + 1}. ${_steps[i].title}',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: Space.x1),
                                  Text(
                                    _steps[i].body,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: Space.x2),
                  child: Text(
                    'Live location, camera and microphone sharing are being '
                    'added step by step. The rules above apply to each one '
                    'as it arrives.',
                    style: theme.textTheme.bodySmall,
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

class _Step {
  const _Step(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}
