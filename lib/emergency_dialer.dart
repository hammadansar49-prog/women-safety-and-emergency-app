import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyDialer extends StatefulWidget {
  const EmergencyDialer({super.key, this.openDialer});

  final Future<bool> Function(Uri)? openDialer;

  @override
  State<EmergencyDialer> createState() => _EmergencyDialerState();
}

class _EmergencyDialerState extends State<EmergencyDialer> {
  bool _opening = false;

  Future<void> _open() async {
    setState(() => _opening = true);
    var opened = false;
    try {
      final uri = Uri(scheme: 'tel', path: '15');
      opened =
          await (widget.openDialer?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    setState(() => _opening = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open the dialer. Use your phone to dial 15 manually.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        onPressed: _opening ? null : _open,
        icon: const Icon(Icons.phone_outlined),
        label: const Text('Open dialer: 15'),
      ),
      const Text(
        'Pakistan police emergency. Complete the call in your phone dialer. '
        'SafeHer does not place an AI call or confirm police dispatch.',
        style: TextStyle(fontSize: 12),
      ),
    ],
  );
}
