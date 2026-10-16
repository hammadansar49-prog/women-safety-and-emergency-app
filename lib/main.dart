import 'package:flutter/material.dart';
import 'emergency_controller.dart';
import 'social_controller.dart';
import 'contacts_screen.dart';
import 'username_screen.dart';

void main() => runApp(const SafeHerApp());

class SafeHerApp extends StatelessWidget {
  const SafeHerApp({super.key, this.social});
  final SocialController? social;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SafeHer',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6552A3)),
      scaffoldBackgroundColor: const Color(0xFFF7F6FB),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF7F6FB),
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(elevation: 0, color: Colors.white),
    ),
    home: SafeHerShell(social: social),
  );
}

class SafeHerShell extends StatefulWidget {
  const SafeHerShell({super.key, this.social});
  final SocialController? social;
  @override
  State<SafeHerShell> createState() => _SafeHerShellState();
}

class _SafeHerShellState extends State<SafeHerShell> {
  final emergency = EmergencyController();
  late final SocialController social;
  String? sosOwner;
  String? activeEventId;
  bool onboarded = false;
  int page = 0;
  @override
  void initState() {
    super.initState();
    social = widget.social ?? SocialController(newAccount: true);
    emergency.addListener(_syncEmergency);
  }

  void _startSos() {
    if (social.eligibleRecipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choose a favorite SOS contact and get their approval first.',
          ),
        ),
      );
      setState(() => page = 1);
      return;
    }
    sosOwner = social.currentUserId;
    emergency.start();
  }

  void _syncEmergency() {
    if (emergency.status == EmergencyStatus.active && activeEventId == null) {
      try {
        if (social.currentUserId != sosOwner) {
          throw StateError('Account changed during countdown.');
        }
        activeEventId = social.createSos().id;
      } on StateError {
        emergency.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'SOS was not started: no approved favorite contacts remain.',
            ),
          ),
        );
      }
    }
  }

  Widget _routeSosBanner(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([emergency, social]),
    builder: (context, _) {
      if (emergency.status == EmergencyStatus.idle ||
          social.currentUserId != sosOwner) {
        return const SizedBox.shrink();
      }
      return Material(
        color: const Color(0xFFFCE4EA),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                emergency.status == EmergencyStatus.countdown
                    ? 'SOS starts in ${emergency.remaining}s'
                    : 'SOS active · not delivered',
              ),
              TextButton(
                onPressed: () => _finishSos(cancelled: true),
                child: const Text('Cancel SOS'),
              ),
            ],
          ),
        ),
      );
    },
  );

  void _finishSos({required bool cancelled}) {
    if (social.currentUserId != sosOwner) return;
    if (activeEventId != null) {
      social.finishSos(activeEventId!, cancelled: cancelled);
    }
    if (cancelled) {
      emergency.cancel();
    } else {
      emergency.resolve();
    }
    activeEventId = null;
    sosOwner = null;
  }

  @override
  void dispose() {
    emergency.dispose();
    if (widget.social == null) social.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([emergency, social]),
    builder: (context, _) {
      if (!onboarded) return _welcome();
      if (social.currentUser.username.isEmpty) {
        return UsernameScreen(
          key: ValueKey(social.currentUserId),
          social: social,
        );
      }
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'SafeHer',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              tooltip: 'Account settings',
              onPressed: () => setState(() => page = 3),
              icon: CircleAvatar(
                radius: 17,
                child: Text(social.currentUser.name.substring(0, 1)),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Column(
          children: [
            if (emergency.status != EmergencyStatus.idle &&
                sosOwner == social.currentUserId &&
                page != 0)
              Material(
                color: const Color(0xFFFCE4EA),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    children: [
                      Text(
                        emergency.status == EmergencyStatus.countdown
                            ? 'SOS starts in ${emergency.remaining}s'
                            : 'SOS active · not delivered',
                      ),
                      TextButton(
                        onPressed: () => _finishSos(cancelled: true),
                        child: const Text('Cancel SOS'),
                      ),
                      TextButton(
                        onPressed: () => setState(() => page = 0),
                        child: const Text('View SOS'),
                      ),
                    ],
                  ),
                ),
              ),
            for (final event in social.visibleEvents.where(
              (e) =>
                  e.senderId != social.currentUserId &&
                  e.status == LocalSosStatus.active,
            ))
              Material(
                color: const Color(0xFFFCE4EA),
                child: ListTile(
                  leading: const Icon(Icons.sos, color: Colors.red),
                  title: Text('SOS from ${social.person(event.senderId).name}'),
                  subtitle: const Text(
                    'Location unavailable. Connection required.',
                  ),
                  trailing: TextButton(
                    onPressed: () => setState(() => page = 2),
                    child: const Text('View'),
                  ),
                ),
              ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 650),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      if (page == 0) ..._home(),
                      if (page == 1)
                        ContactsScreen(
                          key: ValueKey(social.currentUserId),
                          social: social,
                          safetyBannerBuilder: _routeSosBanner,
                        ),
                      if (page == 2) ..._history(),
                      if (page == 3) ..._settings(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: page,
          onDestinationSelected: (value) => setState(() => page = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.shield_outlined),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              label: 'Contacts',
            ),
            NavigationDestination(icon: Icon(Icons.history), label: 'Activity'),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              label: 'Settings',
            ),
          ],
        ),
      );
    },
  );

  Widget _welcome() => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.shield_rounded,
                size: 100,
                color: Color(0xFF6552A3),
              ),
              const SizedBox(height: 28),
              const Text(
                'SafeHer',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800),
              ),
              const Text(
                'Your Safety, Our Priority.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 40),
              _panel(
                Icons.people_outline,
                'Your trusted circle',
                'Choose who can help. Friendship and emergency access require separate consent.',
              ),
              _panel(
                Icons.location_on_outlined,
                'Share on your terms',
                'Location is shared only during an explicitly enabled session. Camera and microphone use must be visible.',
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => setState(() => onboarded = true),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('Get started'),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your circle. Your choice. Your safety.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  List<Widget> _home() {
    final ownEvent = sosOwner == social.currentUserId;
    final active = ownEvent && emergency.status == EmergencyStatus.active;
    final counting = ownEvent && emergency.status == EmergencyStatus.countdown;
    return [
      const Text(
        'A little peace of mind.',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      const Text(
        'Your trusted circle. One simple action.',
        style: TextStyle(fontSize: 16, color: Colors.black54),
      ),
      const SizedBox(height: 24),
      _panel(
        Icons.info_outline,
        'Your safety, one touch away',
        'Choose the people you trust. Select approved favorite contacts for your SOS.',
      ),
      const SizedBox(height: 28),
      Center(
        child: Semantics(
          label: 'Start SOS countdown',
          button: true,
          child: SizedBox(
            width: 220,
            height: 220,
            child: FilledButton(
              onPressed: emergency.status == EmergencyStatus.idle
                  ? _startSos
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC73550),
                disabledBackgroundColor: const Color(0xFFC73550),
                disabledForegroundColor: Colors.white,
                shape: const CircleBorder(),
                elevation: 10,
                shadowColor: const Color(0x55C73550),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sos, size: 64),
                  Text(
                    counting
                        ? '${emergency.remaining}'
                        : active
                        ? 'SOS ACTIVE'
                        : 'START SOS',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 24),
      Text(
        counting
            ? 'SOS starts in ${emergency.remaining} seconds'
            : active
            ? 'SOS active · not delivered'
            : emergency.status != EmergencyStatus.idle
            ? 'Another account has an active SOS'
            : 'Tap to start an SOS',
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
      ),
      if (counting || active) ...[
        const SizedBox(height: 16),
        FilledButton.tonal(
          onPressed: () => _finishSos(cancelled: counting),
          child: Text(counting ? 'Cancel countdown' : 'I am safe'),
        ),
        if (active)
          TextButton(
            onPressed: () => _finishSos(cancelled: true),
            child: const Text('Cancel SOS / false alarm'),
          ),
      ],
      const SizedBox(height: 28),
      _panel(
        Icons.people_outline,
        '${social.eligibleRecipients.length} ready favorite SOS contacts',
        social.eligibleRecipients.isEmpty
            ? 'Open Contacts, add a friend, then hold their name for 1.5 seconds to select them for SOS. They must approve.'
            : 'SOS recipients: ${social.eligibleRecipients.map((p) => p.name).join(', ')}. Other friends will not receive SOS.',
      ),
      TextButton.icon(
        onPressed: () => setState(() => page = 1),
        icon: const Icon(Icons.people_outline),
        label: const Text('Manage friends & SOS favorites'),
      ),
      _panel(
        Icons.location_off_outlined,
        'Location is not being shared',
        'Location access is off. Your location is not being shared.',
      ),
    ];
  }

  List<Widget> _history() => [
    _heading('Your activity', 'Your SOS history and updates.'),
    for (final event in social.visibleEvents.reversed)
      _panel(
        Icons.sos,
        '${social.person(event.senderId).name} · ${event.status.name}',
        '${event.createdAt.toLocal().toString().substring(0, 16)}\nSelected recipients: ${event.recipientIds.map((id) => social.person(id).name).join(', ')}\nDelivery: not connected.',
      ),
    if (social.visibleEvents.isEmpty)
      _panel(
        Icons.history,
        'A fresh start',
        'Your SOS activity will appear here.',
      ),
    const SizedBox(height: 16),
    const Text('History is not synced to an account yet.'),
  ];

  List<Widget> _settings() => [
    _heading('Make it yours', 'Understand what your app can do.'),
    Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Account',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            DropdownButton<String>(
              key: const ValueKey('profile-switch'),
              value: social.currentUserId,
              items: [
                for (final person in social.profiles)
                  DropdownMenuItem(value: person.id, child: Text(person.name)),
              ],
              onChanged: emergency.status == EmergencyStatus.countdown
                  ? null
                  : (id) {
                      if (id != null) social.switchProfile(id);
                    },
            ),
            Text(
              '@${social.currentUser.username}',
              style: const TextStyle(color: Colors.black54),
            ),
            if (emergency.status == EmergencyStatus.countdown)
              const Text(
                'Finish or cancel the countdown before switching accounts.',
              ),
          ],
        ),
      ),
    ),
    Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SOS countdown',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 3, label: Text('3 sec')),
                ButtonSegment(value: 5, label: Text('5 sec')),
                ButtonSegment(value: 10, label: Text('10 sec')),
              ],
              selected: {emergency.countdownSeconds},
              onSelectionChanged: (values) =>
                  setState(() => emergency.countdownSeconds = values.first),
            ),
          ],
        ),
      ),
    ),
    _panel(
      Icons.cloud_off_outlined,
      'Connection unavailable',
      'Messages and alerts are not delivered to other devices. Account sync is unavailable.',
    ),
    _panel(
      Icons.videocam_off_outlined,
      'Media is optional',
      'You control camera and microphone access. Calls are currently unavailable.',
    ),
    _panel(
      Icons.touch_app_outlined,
      'Device shortcuts',
      'Hardware shortcuts are unavailable on this device. Use the SOS button on Home.',
    ),
    _panel(
      Icons.privacy_tip_outlined,
      'Privacy first',
      'Control who receives your SOS in Contacts. You can remove a favorite or revoke approval at any time.',
    ),
  ];

  Widget _heading(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(subtitle),
      ],
    ),
  );
  Widget _panel(IconData icon, String title, String detail) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF6552A3)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  detail,
                  style: const TextStyle(height: 1.45, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
