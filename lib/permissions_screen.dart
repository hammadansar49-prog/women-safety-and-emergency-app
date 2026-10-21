import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'theme/tokens.dart';
import 'ui/design.dart';

/// What SafeHer may use. Each permission is the user's to give; nothing turns
/// on silently. Location is real; camera and microphone arrive with SOS media.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _location = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final p = await Geolocator.checkPermission();
      if (mounted) {
        setState(
          () => _location =
              p == LocationPermission.always ||
              p == LocationPermission.whileInUse,
        );
      }
    } catch (_) {}
  }

  Future<void> _toggleLocation(bool on) async {
    if (!on) {
      // The OS owns revoking; send the user to the right place.
      try {
        await Geolocator.openAppSettings();
      } catch (_) {}
      return;
    }
    final ok = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: const Color(0x73351626),
      transitionDuration: const Duration(milliseconds: 420),
      transitionBuilder: (context, anim, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(
            begin: 0.88,
            end: 1.0,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
          child: child,
        ),
      ),
      pageBuilder: (dialogContext, _, _) => Center(
        child: Material(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.tint,
                    ),
                    child: Icon(
                      Icons.place_outlined,
                      color: AppColors.accent,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Allow SafeHer to use your location?',
                    textAlign: TextAlign.center,
                    style: Theme.of(dialogContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your location is shared only while an SOS you started is active.',
                    textAlign: TextAlign.center,
                    style: Theme.of(dialogContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedPill(
                          label: "Don't allow",
                          onTap: () => Navigator.of(dialogContext).pop(false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: BerryButton(
                          label: 'Allow',
                          onTap: () => Navigator.of(dialogContext).pop(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await Geolocator.requestPermission();
    } catch (_) {}
    await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: HeaderPage(
      headerHeight: 220,
      overlap: 24,
      bottomPadding: 40,
      header: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeaderBack(),
          HeaderTitle(
            'Permissions',
            subtitle: 'You allow each one yourself. Nothing turns on silently.',
            size: 30,
          ),
        ],
      ),
      children: [
        RowCard(
          leading: const IconChip(Icons.place_outlined, size: 42),
          title: 'Live location',
          detail: 'Shared only during an SOS you start',
          trailing: SoftSwitch(
            value: _location,
            label: 'Live location',
            onChanged: _toggleLocation,
          ),
        ),
        RowCard(
          leading: const IconChip(Icons.photo_camera_outlined, size: 42),
          title: 'Camera',
          detail: 'Arrives with SOS camera sharing',
          trailing: const SoftSwitch(value: false, onChanged: null),
        ),
        RowCard(
          leading: const IconChip(Icons.mic_none_rounded, size: 42),
          title: 'Microphone',
          detail: 'Arrives with SOS audio sharing',
          trailing: const SoftSwitch(value: false, onChanged: null),
        ),
        RowCard(
          leading: const IconChip(Icons.notifications_none_rounded, size: 42),
          title: 'Notifications',
          detail: 'Arrives with cloud delivery',
          trailing: const SoftSwitch(value: false, onChanged: null),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: AppColors.tint,
          ),
          child: Text(
            'If you say no to one, that part is simply not shared. You can change this any time in your phone settings.',
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ],
    ),
  );
}
