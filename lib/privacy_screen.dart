import 'package:flutter/material.dart';

import 'theme/tokens.dart';
import 'ui/design.dart';

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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: HeaderPage(
        headerHeight: 210,
        overlap: -22,
        bottomPadding: 40,
        header: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HeaderBack(),
            HeaderTitle(
              'You are in control.',
              subtitle:
                  'Making a buddy never starts an SOS or shares your data.',
              size: 30,
            ),
          ],
        ),
        children: [
          const SizedBox(height: 18),
          for (var i = 0; i < _steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.secondary,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.onHeader,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _steps[i].title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _steps[i].body,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12.5,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Live location, camera and microphone sharing are being added step by step. The rules above apply to each one as it arrives.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
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
