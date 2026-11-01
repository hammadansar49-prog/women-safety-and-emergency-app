import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'social_controller.dart';
import 'theme/tokens.dart';
import 'ui/design.dart';

/// "I'm walking home": shares live location with approved buddies until
/// arrival. Starting a trip also sets a check-in for the same time, so a
/// trip that never ends turns into an SOS.
class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.social});
  final SocialController social;

  static const _options = {30: '30 min', 60: '1 hour', 120: '2 hours'};

  void _start(BuildContext context, int minutes) {
    final within = Duration(minutes: minutes);
    if (!social.startTrip(within)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add an SOS buddy who has approved you first.'),
        ),
      );
      return;
    }
    social.setCheckIn(within);
  }

  void _arrived() {
    social.endTrip();
    social.setCheckIn(null);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: social,
    builder: (context, _) {
      final theme = Theme.of(context);
      final until = social.tripUntil;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final t in social.buddyTrips)
            RowCard(
              leading: const IconChip(Icons.directions_walk_rounded),
              title: '${social.person(t.sender).name} is on the way',
              detail: t.lat == null
                  ? 'Waiting for their location'
                  : 'Until ${TimeOfDay.fromDateTime(t.until.toLocal()).format(context)} · tap for map',
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
              onTap: t.lat == null
                  ? null
                  : () => launchUrl(
                      Uri.parse(
                        'https://www.google.com/maps/search/?api=1&query='
                        '${t.lat},${t.lng}',
                      ),
                      mode: LaunchMode.externalApplication,
                    ),
            ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IconChip(Icons.route_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Share my trip',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            until == null
                                ? 'Buddies see you live until you arrive.'
                                : 'Sharing live until ${TimeOfDay.fromDateTime(until).format(context)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (until == null)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in _options.entries)
                        PillButton(
                          label: e.value,
                          tone: (AppColors.tint, AppColors.textMuted),
                          onTap: () => _start(context, e.key),
                        ),
                    ],
                  )
                else
                  PillButton(
                    label: "I've arrived",
                    filled: true,
                    onTap: _arrived,
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
