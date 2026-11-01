import 'package:flutter/material.dart';

import 'social_controller.dart';
import 'theme/tokens.dart';
import 'ui/design.dart';

/// Safe-walk check-in: "SOS my buddies unless I confirm I'm safe within N
/// minutes". The timer itself lives in the app shell so it keeps running on
/// every tab; this card only sets and clears it.
class CheckInCard extends StatelessWidget {
  const CheckInCard({super.key, required this.social});
  final SocialController social;

  static const _options = {15: '15 min', 30: '30 min', 60: '1 hour'};

  String _left(DateTime due) {
    final d = due.difference(DateTime.now());
    if (d.isNegative) return 'due now';
    if (d.inMinutes < 1) return 'under a minute left';
    return '${d.inMinutes} min left';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: social,
    builder: (context, _) {
      final theme = Theme.of(context);
      final due = social.checkInDue;
      return Container(
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
                const IconChip(Icons.timer_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Safe-walk check-in',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        due == null
                            ? 'SOS starts if you do not check in on time.'
                            : 'Check in by ${TimeOfDay.fromDateTime(due).format(context)} · ${_left(due)}',
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
            if (due == null)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in _options.entries)
                    PillButton(
                      label: e.value,
                      tone: (AppColors.tint, AppColors.textMuted),
                      onTap: () => social.setCheckIn(Duration(minutes: e.key)),
                    ),
                ],
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PillButton(
                    label: "I'm safe",
                    filled: true,
                    onTap: () => social.setCheckIn(null),
                  ),
                  PillButton(
                    label: '+15 min',
                    tone: (AppColors.tint, AppColors.textMuted),
                    onTap: () => social.setCheckIn(
                      due.difference(DateTime.now()) +
                          const Duration(minutes: 15),
                    ),
                  ),
                ],
              ),
          ],
        ),
      );
    },
  );
}
