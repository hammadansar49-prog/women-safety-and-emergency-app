import 'package:flutter/material.dart';
import 'emergency_controller.dart';

void main() => runApp(const SafeHerApp());

class SafeHerApp extends StatelessWidget {
  const SafeHerApp({super.key});
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
    home: const SafeHerShell(),
  );
}

class SafeHerShell extends StatefulWidget {
  const SafeHerShell({super.key});
  @override
  State<SafeHerShell> createState() => _SafeHerShellState();
}

class _SafeHerShellState extends State<SafeHerShell> {
  final emergency = EmergencyController();
  bool onboarded = false;
  int page = 0;
  @override
  void dispose() {
    emergency.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: emergency,
    builder: (context, _) {
      if (!onboarded) return _welcome();
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'SafeHer',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 20),
              child: Chip(
                avatar: Icon(Icons.science_outlined, size: 16),
                label: Text('Demo mode'),
              ),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (page == 0) ..._home(),
                if (page == 1) ..._contacts(),
                if (page == 2) ..._history(),
                if (page == 3) ..._settings(),
                const SizedBox(height: 24),
              ],
            ),
          ),
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
                  child: Text('Explore demo'),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Local demonstration only. Google sign-in and real alerts require Firebase setup.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  List<Widget> _home() {
    final active = emergency.status == EmergencyStatus.active;
    final counting = emergency.status == EmergencyStatus.countdown;
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
        'Practice safely',
        'This demo does not send notifications, capture media, or share your location.',
      ),
      const SizedBox(height: 28),
      Center(
        child: Semantics(
          label: 'Start demonstration SOS countdown',
          button: true,
          child: SizedBox(
            width: 220,
            height: 220,
            child: FilledButton(
              onPressed: emergency.status == EmergencyStatus.idle
                  ? emergency.start
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
                        ? 'DEMO ACTIVE'
                        : 'START DEMO',
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
            ? 'Demo starts in ${emergency.remaining} seconds'
            : active
            ? 'Demo SOS active — no alerts sent'
            : 'Tap to practice an SOS',
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
      ),
      if (counting || active) ...[
        const SizedBox(height: 16),
        FilledButton.tonal(
          onPressed: counting ? emergency.cancel : emergency.resolve,
          child: Text(counting ? 'Cancel countdown' : 'Resolve demo'),
        ),
        if (active)
          TextButton(
            onPressed: emergency.cancel,
            child: const Text('Cancel demo / false alarm'),
          ),
      ],
      const SizedBox(height: 28),
      _panel(
        Icons.people_outline,
        '0 trusted contacts',
        'Connect Firebase to find friends and mutually confirm emergency contacts.',
      ),
      _panel(
        Icons.location_off_outlined,
        'Location is not being shared',
        'Live location becomes available in the connected app with your permission.',
      ),
    ];
  }

  List<Widget> _contacts() => [
    _heading('Your trusted circle', 'People you choose. Access you control.'),
    _panel(
      Icons.person_add_alt,
      'Connect with someone you trust',
      'The connected app will let you search by username or invitation code.',
    ),
    _panel(
      Icons.handshake_outlined,
      'Two people. Clear consent.',
      'Accepting a friend request does not grant emergency access. Both people must confirm trusted-contact status, and either can revoke it.',
    ),
    const SizedBox(height: 32),
    const Icon(Icons.people_outline, size: 72, color: Color(0xFF6552A3)),
    const SizedBox(height: 16),
    const Text(
      'No trusted contacts yet',
      textAlign: TextAlign.center,
      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
    ),
    const SizedBox(height: 8),
    const Text(
      'Firebase is not configured. No contact requests can be sent in this demo.',
      textAlign: TextAlign.center,
    ),
  ];

  List<Widget> _history() => [
    _heading('Your activity', 'Local practice events from this session.'),
    if (emergency.history.isEmpty)
      _panel(
        Icons.history,
        'A fresh start',
        'Your completed or cancelled demo events will appear here.',
      ),
    for (final item in emergency.history)
      _panel(
        Icons.check_circle_outline,
        item,
        'Practice event • no notifications sent',
      ),
    const SizedBox(height: 16),
    const Text(
      'Demo activity is held in memory and clears when the app restarts.',
    ),
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
      'Firebase not connected',
      'Google sign-in, trusted contacts, push notifications and live location require project configuration.',
    ),
    _panel(
      Icons.videocam_off_outlined,
      'Media is optional',
      'A future live session will require consent and visible camera/microphone controls. Media availability must never block SOS.',
    ),
    _panel(
      Icons.touch_app_outlined,
      'Device shortcuts',
      'Power-button interception is not universally available. Hardware shortcuts are not enabled in this foundation.',
    ),
    _panel(
      Icons.privacy_tip_outlined,
      'Privacy first',
      'This demo stores no account or location data. Live account deletion and retention controls will be added with the backend.',
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
