import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme/tokens.dart';
import 'ui/design.dart';

/// A national emergency number the user can dial in one tap.
typedef Helpline = ({String name, String number, IconData icon});

/// Pakistan's emergency numbers, shown on Home so help is reachable even
/// when no buddy is approved or the phone has no internet.
const List<Helpline> pakistanHelplines = [
  (name: 'Police', number: '15', icon: Icons.local_police_outlined),
  (name: 'Rescue / Ambulance', number: '1122', icon: Icons.emergency_outlined),
  (name: 'Madadgar (women & children)', number: '1099', icon: Icons.support_agent),
  (name: 'Edhi Ambulance', number: '115', icon: Icons.local_hospital_outlined),
];

class HelplineList extends StatelessWidget {
  const HelplineList({super.key, this.helplines = pakistanHelplines});
  final List<Helpline> helplines;

  Future<void> _dial(BuildContext context, String number) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launchUrl(Uri(scheme: 'tel', path: number));
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open the dialer. Call $number.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Emergency helplines',
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        for (final h in helplines)
          RowCard(
            leading: IconChip(h.icon),
            title: h.name,
            detail: 'Call ${h.number}',
            trailing: Icon(Icons.call, color: AppColors.accent),
            onTap: () => _dial(context, h.number),
          ),
      ],
    );
  }
}
