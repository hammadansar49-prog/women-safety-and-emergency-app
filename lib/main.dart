import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'emergency_controller.dart';
import 'firebase_options.dart';
import 'social_controller.dart';
import 'contacts_screen.dart';
import 'username_screen.dart';
import 'local_store.dart';
import 'auth_screens.dart';
import 'auth_service.dart';
import 'privacy_screen.dart';
import 'profile_photo.dart';
import 'sos_shortcut.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'ui/aurora_background.dart';
import 'ui/glass.dart';
import 'ui/motion.dart';
import 'ui/sos_button.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Connect Firebase only where it is configured (Android for now). Other
  // platforms keep running in local-only mode so nothing breaks before their
  // Firebase apps are registered.
  if (DefaultFirebaseOptions.hasPlatformOptions) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (_) {
      // A failed Firebase init must not block the app from opening; features
      // that need the cloud will report their own errors.
    }
  }
  try {
    final social = await loadLocalAccount();
    try {
      await recoverProfilePhoto(social);
    } catch (_) {
      social.saveError =
          'Could not recover the selected photo. Please choose it again.';
    }
    runApp(SafeHerApp(social: social));
  } catch (_) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Saved data could not be opened. Your data has not been reset.',
                ),
                FilledButton(onPressed: main, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SafeHerApp extends StatefulWidget {
  const SafeHerApp({super.key, this.social});
  final SocialController? social;
  @override
  State<SafeHerApp> createState() => _SafeHerAppState();
}

class _SafeHerAppState extends State<SafeHerApp> with WidgetsBindingObserver {
  late final SocialController social =
      widget.social ?? SocialController(newAccount: true);
  ThemeMode get themeMode => ThemeMode.values.byName(social.appearance);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// "System" follows the device, including its automatic day/night schedule.
  @override
  void didChangePlatformBrightness() {
    if (mounted) setState(() {});
  }

  bool get _useLight => switch (themeMode) {
    ThemeMode.light => true,
    ThemeMode.dark => false,
    ThemeMode.system =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.light,
  };

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.social == null) social.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: social,
    builder: (context, _) {
      // The palette is global: set it before the theme (and every widget that
      // reads AppColors) is built for this frame.
      AppColors.light = _useLight;
      return MaterialApp(
        title: 'SafeHer',
        debugShowCheckedModeBanner: false,
        // The active palette is global (set above), so both slots build the same
        // theme and themeMode just picks one.
        theme: AppTheme.build(),
        darkTheme: AppTheme.build(),
        themeMode: _useLight ? ThemeMode.light : ThemeMode.dark,
        builder: (context, child) =>
            AuroraBackground(child: child ?? const SizedBox.shrink()),
        home: SafeHerShell(
          social: social,
          themeMode: themeMode,
          onThemeChanged: (mode) => social.setAppearance(mode.name),
        ),
      );
    },
  );
}

class SafeHerShell extends StatefulWidget {
  const SafeHerShell({
    super.key,
    this.social,
    this.themeMode = ThemeMode.system,
    this.onThemeChanged,
    this.auth,
  });
  final AuthService? auth;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeChanged;
  final SocialController? social;
  @override
  State<SafeHerShell> createState() => _SafeHerShellState();
}

/// The auth surface shown before the user reaches the app.
enum _AuthStage { welcome, login, register }

AuthService _defaultAuth() =>
    Firebase.apps.isNotEmpty ? FirebaseAuthService() : LocalAuthService();

class _SafeHerShellState extends State<SafeHerShell> {
  final emergency = EmergencyController();
  late final SosShortcut shortcut;
  late final SocialController social;
  late final AuthService auth;
  String? sosOwner;
  String? activeEventId;

  /// Which auth surface is showing while the user is not yet signed in.
  _AuthStage _stage = _AuthStage.welcome;

  /// "In the app" means signed in AND a username exists. Google sign-in lands
  /// signed-in-but-no-username, which routes to the username step first.
  bool get onboarded =>
      social.signedIn && social.currentUser.username.isNotEmpty;

  int page = 0;
  @override
  void initState() {
    super.initState();
    social = widget.social ?? SocialController(newAccount: true);
    auth = widget.auth ?? _defaultAuth();
    // Local preview mode: an already signed-in profile also gets the demo buddy.
    if (auth is LocalAuthService &&
        social.signedIn &&
        social.currentUser.username.isNotEmpty) {
      social.seedDemoFriend('ayesha');
    }
    shortcut = SosShortcut(
      selectedKey: social.shortcutKey,
      onSos: () {
        if (!mounted || !onboarded || !social.signedIn) return;
        if (emergency.status == EmergencyStatus.idle) {
          _startSos();
        } else if (social.currentUserId == sosOwner) {
          // Same gesture during an active/counting SOS is the hidden cancel.
          // Nothing about this is shown on screen; the onboarding guide teaches
          // the gesture instead.
          _finishSos(cancelled: true);
        }
      },
    );
    emergency.countdownSeconds = social.countdown;
    for (final event in social.visibleEvents) {
      if (event.senderId == social.currentUserId &&
          event.status == LocalSosStatus.active) {
        sosOwner = event.senderId;
        activeEventId = event.id;
        emergency.status = EmergencyStatus.active;
      }
    }
    emergency.addListener(_syncEmergency);
  }

  // --- Auth flow -----------------------------------------------------------
  // Real Firebase Auth where configured (Android); an in-memory stand-in with
  // the same rules elsewhere.

  Future<String?> _handleLogin(String username, String password) async {
    try {
      final name = await auth.login(username: username, password: password);
      _enter(name);
      return null;
    } on AuthFailure catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not sign in. Try again.';
    }
  }

  Future<String?> _handleRegister(
    String email,
    String username,
    String password,
  ) async {
    final taken = social.usernameError(username);
    if (taken != null) return taken;
    try {
      final name = await auth.register(
        email: email,
        username: username,
        password: password,
      );
      _enter(name);
      return null;
    } on AuthFailure catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not create the account. Try again.';
    }
  }

  /// Opens the real Google account chooser. An account with no username yet
  /// lands on the username step.
  Future<String?> _handleGoogle() async {
    try {
      final name = await auth.google();
      _enter(name);
      return null;
    } on AuthFailure catch (e) {
      return e.message;
    } catch (_) {
      return 'Google sign-in failed. Try again.';
    }
  }

  void _enter(String username) {
    if (username.isNotEmpty) social.claimUsername(username);
    // Local preview mode has nobody to talk to, so seed one demo buddy.
    if (auth is LocalAuthService) social.seedDemoFriend('ayesha');
    social.setSignedIn(true);
    if (mounted) setState(() {});
  }

  Widget _storageStatus() {
    if (social.saveError != null) {
      return Material(
        color: Theme.of(context).colorScheme.errorContainer,
        child: ListTile(
          title: Text(social.saveError!),
          trailing: TextButton(
            onPressed: social.retrySave,
            child: const Text('Retry'),
          ),
        ),
      );
    }
    if (social.saving) return const LinearProgressIndicator();
    return const SizedBox.shrink();
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => ListenableBuilder(
          listenable: Listenable.merge([social, emergency]),
          builder: (context, _) => Scaffold(
            appBar: AppBar(title: const Text('Profile')),
            body: Column(
              children: [
                _routeSosBanner(context),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 650),
                      child: ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          ProfilePhotoEditor(social: social),
                          _storageStatus(),
                          const SizedBox(height: 20),
                          Text(
                            social.currentUser.name,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 20),
                          Card(
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.alternate_email),
                                  title: const Text('Username'),
                                  subtitle: Text(
                                    '@${social.currentUser.username}',
                                  ),
                                ),
                                const ListTile(
                                  leading: Icon(Icons.email_outlined),
                                  title: Text('Google email'),
                                  subtitle: Text(
                                    'Google account not connected',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.tonalIcon(
                            onPressed: emergency.status != EmergencyStatus.idle
                                ? null
                                : () async {
                                    try {
                                      await social.flush();
                                      shortcut.enable(false);
                                      await auth.signOut();
                                      social.signOut();
                                      await social.flush();
                                    } catch (_) {
                                      return;
                                    }
                                    if (!routeContext.mounted || !mounted) {
                                      return;
                                    }
                                    Navigator.of(routeContext).pop();
                                    setState(() {
                                      _stage = _AuthStage.welcome;
                                      page = 0;
                                    });
                                  },
                            icon: const Icon(Icons.logout),
                            label: const Text('Log out'),
                          ),
                          if (emergency.status != EmergencyStatus.idle)
                            const Text(
                              'Finish or cancel the SOS before logging out.',
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
        color: Theme.of(context).colorScheme.errorContainer,
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
    shortcut.dispose();
    emergency.dispose();
    if (widget.social == null) social.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([emergency, social]),
    builder: (context, _) {
      // Not signed in → the auth sub-flow.
      if (!social.signedIn) {
        switch (_stage) {
          case _AuthStage.welcome:
            return _welcome();
          case _AuthStage.login:
            return LoginScreen(
              onLogin: _handleLogin,
              onGoogle: _handleGoogle,
              onCreateAccount: () =>
                  setState(() => _stage = _AuthStage.register),
            );
          case _AuthStage.register:
            return RegisterScreen(
              onRegister: _handleRegister,
              onGoogle: _handleGoogle,
              onBackToLogin: () => setState(() => _stage = _AuthStage.login),
            );
        }
      }
      // Signed in (e.g. via Google) but no username yet → choose one.
      if (social.currentUser.username.isEmpty) {
        return UsernameScreen(
          key: ValueKey(social.currentUserId),
          social: social,
          onReserve: auth.reserveUsername,
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
              tooltip: 'Profile',
              onPressed: _openProfile,
              icon: profileAvatar(social, 17),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Column(
          children: [
            _storageStatus(),
            if (emergency.status != EmergencyStatus.idle &&
                sosOwner == social.currentUserId &&
                page != 0)
              Material(
                color: Theme.of(context).colorScheme.errorContainer,
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
                color: Theme.of(context).colorScheme.errorContainer,
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
                    padding: _pagePadding(context),
                    children: [
                      if (page == 0) ..._home(),
                      if (page == 1)
                        ContactsScreen(
                          key: ValueKey(social.currentUserId),
                          social: social,
                          safetyBannerBuilder: _routeSosBanner,
                          searchRemote: auth.searchUsers,
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
        extendBody: true,
        backgroundColor: Colors.transparent,
        bottomNavigationBar: _GlassNavBar(
          selectedIndex: page,
          onSelected: (value) => setState(() => page = value),
        ),
      );
    },
  );

  /// Gutters shrink on narrow phones, and the bottom inset clears the
  /// floating nav bar (which overlays the body) plus the system gesture area.
  EdgeInsets _pagePadding(BuildContext context) {
    final media = MediaQuery.of(context);
    final side = media.size.width < 360 ? 16.0 : 24.0;
    return EdgeInsets.fromLTRB(side, 24, side, 24 + 88 + media.padding.bottom);
  }

  Widget _welcome() {
    final theme = Theme.of(context);
    // No scroll, fits every display: the content is laid out at a fixed design
    // width and scaled down uniformly to fit the available height/width. On a
    // roomy screen it stays at natural size (scaleDown never enlarges); on a
    // short screen it shrinks to fit instead of scrolling.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.x6,
            vertical: Space.x6,
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const EntranceFade(child: Center(child: _BrandMark())),
                    const SizedBox(height: Space.x8),
                    EntranceFade(
                      index: 1,
                      child: Text(
                        'SafeHer',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displayLarge,
                      ),
                    ),
                    const SizedBox(height: Space.x2),
                    EntranceFade(
                      index: 2,
                      child: Text(
                        'One button. The people you chose. Nothing shared until you ask.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.x12),
                    _panel(
                      Icons.people_outline,
                      'Your trusted circle',
                      'Choose who can help. Friendship and emergency access are two separate approvals.',
                      index: 3,
                    ),
                    _panel(
                      Icons.location_on_outlined,
                      'Share on your terms',
                      'Location is shared only during an SOS you started. Camera and microphone use always stays visible.',
                      index: 4,
                    ),
                    const SizedBox(height: Space.x8),
                    EntranceFade(
                      index: 5,
                      child: Pressable(
                        borderRadius: Radii.brSm,
                        glow: AppColors.accent,
                        onTap: () => setState(() => _stage = _AuthStage.login),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: Space.x4 + 2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: Radii.brSm,
                            gradient: LinearGradient(
                              colors: [AppColors.accent, AppColors.primary],
                            ),
                            border: Border.all(color: AppColors.glassHairline),
                          ),
                          child: Text(
                            'Get started',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.x6),
                    EntranceFade(
                      index: 6,
                      child: Text(
                        'Your circle. Your choice. Your safety.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _home() {
    final ownEvent = sosOwner == social.currentUserId;
    final active = ownEvent && emergency.status == EmergencyStatus.active;
    final counting = ownEvent && emergency.status == EmergencyStatus.countdown;
    return [
      _heading('A little peace of mind.', 'Your trusted circle. One action.'),
      _panel(
        Icons.info_outline,
        'Your safety, one touch away',
        'Choose the people you trust. Select approved favorite contacts for your SOS.',
        index: 1,
      ),
      const SizedBox(height: Space.x8),
      EntranceFade(
        index: 2,
        child: Center(
          child: SosButton(
            status: ownEvent ? emergency.status : EmergencyStatus.idle,
            remaining: emergency.remaining,
            countdownSeconds: emergency.countdownSeconds,
            enabled:
                emergency.status == EmergencyStatus.idle ||
                (ownEvent && emergency.status != EmergencyStatus.idle),
            // One control, both directions: it starts the SOS, and while one is
            // running it stops it. That mirrors the hidden volume gesture, so
            // the button and the gesture never disagree about what they do.
            onTap: emergency.status == EmergencyStatus.idle
                ? _startSos
                : ownEvent
                ? () => _finishSos(cancelled: true)
                : () {},
          ),
        ),
      ),
      const SizedBox(height: Space.x6),
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
        label: const Text('Manage buddies & SOS favorites'),
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
              'Appearance',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            _Segments<ThemeMode>(
              options: const {
                ThemeMode.system: 'System',
                ThemeMode.light: 'Light',
                ThemeMode.dark: 'Dark',
              },
              selected: widget.themeMode,
              onChanged: (value) => widget.onThemeChanged?.call(value),
            ),
            const SizedBox(height: 12),
            const Text(
              'System follows your device appearance, including its automatic schedule.',
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
            _Segments<int>(
              options: const {3: '3 sec', 5: '5 sec', 10: '10 sec'},
              selected: emergency.countdownSeconds,
              onChanged: (value) => setState(() {
                emergency.countdownSeconds = value;
                social.setCountdown(value);
              }),
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
    ShortcutSettings(shortcut: shortcut, onSelect: social.setShortcutKey),
    _panel(
      Icons.privacy_tip_outlined,
      'Privacy first',
      'Tap to see exactly what is shared, with whom, and how you stay in control.',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PrivacyGuideScreen()),
      ),
    ),
  ];

  Widget _heading(String title, String subtitle) => EntranceFade(
    child: Padding(
      padding: const EdgeInsets.only(bottom: Space.x6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: Space.x2),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    ),
  );

  Widget _panel(
    IconData icon,
    String title,
    String detail, {
    int index = 0,
    VoidCallback? onTap,
  }) => EntranceFade(
    index: index,
    child: Padding(
      padding: const EdgeInsets.only(bottom: Space.x3),
      child: Pressable(
        onTap: onTap,
        child: GlassPanel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The icon sits in its own tinted chip so it reads as an object
              // rather than a glyph floating next to text.
              Container(
                padding: const EdgeInsets.all(Space.x2),
                decoration: BoxDecoration(
                  borderRadius: Radii.brSm,
                  color: AppColors.primary.withValues(alpha: 0.18),
                  border: Border.all(color: AppColors.glassHairline),
                ),
                child: Icon(icon, color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: Space.x4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: Space.x1),
                    Text(detail, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Floating glass navigation.
///
/// It sits over the content (`extendBody: true`) so the aurora keeps running
/// underneath it — which is the whole reason the blur reads as glass here. The
/// selected destination animates its pill and tint rather than snapping, so
/// switching tabs feels like one surface moving instead of four separate icons
/// toggling.
class _GlassNavBar extends StatelessWidget {
  const _GlassNavBar({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = <({IconData icon, IconData active, String label})>[
    (icon: Icons.shield_outlined, active: Icons.shield_rounded, label: 'Home'),
    (
      icon: Icons.people_outline,
      active: Icons.people_rounded,
      label: 'Buddies',
    ),
    (icon: Icons.history, active: Icons.history_rounded, label: 'Activity'),
    (
      icon: Icons.settings_outlined,
      active: Icons.settings_rounded,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.x4, 0, Space.x4, Space.x4),
        // heightFactor 1.0 is the fix for the nav floating mid-screen: a plain
        // Center expands to fill the (loose) bottom-bar height and parks the
        // small glass panel in the middle of it. Wrapping the height to the
        // child pins the bar to the bottom where it belongs.
        child: Align(
          alignment: Alignment.center,
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: GlassPanel(
              borderRadius: Radii.brLg,
              padding: const EdgeInsets.symmetric(
                horizontal: Space.x2,
                vertical: Space.x2,
              ),
              blur: 26,
              opacity: 0.70,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Expanded(
                      child: Pressable(
                        borderRadius: Radii.brMd,
                        onTap: () => onSelected(i),
                        semanticLabel: _items[i].label,
                        hoverLift: 1,
                        child: AnimatedContainer(
                          duration: Motion.standard,
                          curve: Motion.enter,
                          padding: const EdgeInsets.symmetric(
                            vertical: Space.x2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: Radii.brMd,
                            color: selectedIndex == i
                                ? AppColors.primary.withValues(alpha: 0.28)
                                : Colors.transparent,
                            border: Border.all(
                              color: selectedIndex == i
                                  ? AppColors.glassHairline
                                  : Colors.transparent,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedScale(
                                scale: selectedIndex == i ? 1.08 : 1.0,
                                duration: Motion.standard,
                                curve: Motion.spring,
                                child: Icon(
                                  selectedIndex == i
                                      ? _items[i].active
                                      : _items[i].icon,
                                  size: 22,
                                  color: selectedIndex == i
                                      ? AppColors.text
                                      : AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: Space.x1),
                              Text(
                                _items[i].label,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  fontWeight: selectedIndex == i
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: selectedIndex == i
                                      ? AppColors.text
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The shield, lit from within.
///
/// The existing purple shield is SafeHer's established mark, so it is preserved
/// rather than redesigned — it just gains a slow halo so the welcome screen has
/// one living element instead of a flat glyph.
class _BrandMark extends StatefulWidget {
  const _BrandMark();

  @override
  State<_BrandMark> createState() => _BrandMarkState();
}

class _BrandMarkState extends State<_BrandMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat(reverse: true);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context) && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final wave = _controller.value;
      return Container(
        width: 132,
        height: 132,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.30 + 0.10 * wave),
              AppColors.primary.withValues(alpha: 0.0),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.22 + 0.12 * wave),
              blurRadius: 48,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Icon(
          Icons.shield_rounded,
          size: 76,
          color: Color.lerp(AppColors.accent, AppColors.text, 0.25 * wave),
        ),
      );
    },
  );
}

/// A segmented control with equal-width options. Labels are single-line and
/// scale down, so they never wrap on narrow phones.
class _Segments<T> extends StatelessWidget {
  const _Segments({
    required this.options,
    required this.selected,
    required this.onChanged,
  });
  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        for (final entry in options.entries)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(entry.key),
              child: Semantics(
                button: true,
                selected: entry.key == selected,
                label: entry.value,
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: entry.key == selected
                        ? AppColors.accent
                        : Colors.transparent,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      entry.value,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: entry.key == selected
                            ? Colors.black
                            : AppColors.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
