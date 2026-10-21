import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'emergency_controller.dart';
import 'firebase_options.dart';
import 'social_controller.dart';
import 'contacts_screen.dart';
import 'chat_screen.dart';
import 'username_screen.dart';
import 'local_store.dart';
import 'auth_screens.dart';
import 'auth_service.dart';
import 'location_service.dart';
import 'privacy_screen.dart';
import 'profile_photo.dart';
import 'sos_shortcut.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'ui/aurora_background.dart';
import 'ui/glass.dart';
import 'ui/motion.dart';
import 'ui/design.dart';
import 'ui/sos_slider.dart';
import 'profile_screen.dart';
import 'sos_buddies_screen.dart';
import 'permissions_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Connect Firebase only where it is configured (Android for now). Other
  // platforms keep running in local-only mode so nothing breaks before their
  // Firebase apps are registered.
  // `--dart-define=SAFEHER_LOCAL=true` runs fully local (no Firebase) and signs
  // in a demo profile, for design previews and automated checks.
  const localPreview = bool.fromEnvironment('SAFEHER_LOCAL');
  if (!localPreview && DefaultFirebaseOptions.hasPlatformOptions) {
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
    final previewScreen = localPreview
        ? Uri.base.queryParameters['screen']
        : null;
    if (localPreview &&
        !social.signedIn &&
        previewScreen != 'login' &&
        previewScreen != 'register') {
      if (social.currentUser.username.isEmpty && previewScreen != 'username') {
        social.claimUsername('tester_one');
      }
      social.setSignedIn(true);
      social.seedDemoFriend('ayesha');
      social.seedDemoSosBuddy('ayesha');
    }
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
  final tracker = LocationTracker();
  String? sosOwner;
  String? activeEventId;

  /// Which auth surface is showing while the user is not yet signed in.
  _AuthStage _stage = _AuthStage.login;

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
        // The app was reopened mid-SOS: resume the live position stream.
        final resumeId = event.id;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _startTracking(resumeId),
        );
      }
    }
    emergency.addListener(_syncEmergency);
    if (const bool.fromEnvironment('SAFEHER_LOCAL')) {
      final screen = Uri.base.queryParameters['screen'];
      if (screen != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _previewScreen(screen),
        );
      }
    }
  }

  /// Preview builds only: `?screen=chat` opens that screen directly, so every
  /// screen can be captured and compared with the design.
  void _previewScreen(String screen) {
    if (!mounted) return;
    switch (screen) {
      case 'buddies':
        setState(() => page = 1);
      case 'activity':
        setState(() => page = 2);
      case 'settings':
        setState(() => page = 3);
      case 'register':
        setState(() => _stage = _AuthStage.register);
      case 'chat':
        Navigator.of(context).push(
          SafeRoute<void>(
            builder: (_) => ChatScreen(social: social, friendId: 'ayesha'),
          ),
        );
      case 'chatsettings':
        Navigator.of(context).push(
          SafeRoute<void>(
            builder: (_) => ChatSettingsScreen(
              social: social,
              friendId: 'ayesha',
              onToggleSos: () {},
              onCall: (_) {},
            ),
          ),
        );
      case 'sosbuddies':
        _openSosBuddies();
      case 'permissions':
        Navigator.of(
          context,
        ).push(SafeRoute<void>(builder: (_) => const PermissionsScreen()));
      case 'editprofile':
        _openEditProfile();
      case 'privacy':
        Navigator.of(
          context,
        ).push(SafeRoute<void>(builder: (_) => const PrivacyGuideScreen()));
    }
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
        _startTracking(activeEventId!);
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

  /// Streams the position into the active SOS until it is stopped.
  void _startTracking(String eventId) {
    tracker
        .start((fix) {
          if (!mounted) return;
          social.updateSosLocation(
            eventId,
            fix.latitude,
            fix.longitude,
            fix.time,
          );
        })
        .then((started) {
          if (!started && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Location is off or not allowed, so your position is not being shared.',
                ),
              ),
            );
          }
        });
  }

  void _finishSos({required bool cancelled}) {
    if (social.currentUserId != sosOwner) return;
    final eventId = activeEventId;
    if (eventId != null) {
      // Tracking ends with the SOS; the last fix becomes the "ended here" point.
      tracker.stop().then((last) {
        if (last != null) {
          social.updateSosLocation(
            eventId,
            last.latitude,
            last.longitude,
            last.time,
          );
        }
      });
      social.finishSos(eventId, cancelled: cancelled);
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
      final ownSos =
          sosOwner == social.currentUserId &&
          emergency.status != EmergencyStatus.idle;
      return Stack(
        fit: StackFit.expand,
        children: [
          Scaffold(
            body: Column(
              children: [
                _storageStatus(),
                for (final event in social.visibleEvents.where(
                  (e) =>
                      e.senderId != social.currentUserId &&
                      e.status == LocalSosStatus.active,
                ))
                  Material(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: SafeArea(
                      bottom: false,
                      child: ListTile(
                        leading: Icon(Icons.sos, color: AppColors.danger),
                        title: Text(
                          'SOS from ${social.person(event.senderId).name}',
                        ),
                        subtitle: const Text(
                          'Location unavailable. Connection required.',
                        ),
                        trailing: TextButton(
                          onPressed: () => setState(() => page = 2),
                          child: const Text('View'),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: Motion.page,
                    switchInCurve: Motion.enter,
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: KeyedSubtree(
                      key: ValueKey(page),
                      child: switch (page) {
                        0 => _homePage(),
                        1 => ContactsScreen(
                          key: ValueKey(social.currentUserId),
                          social: social,
                          safetyBannerBuilder: _routeSosBanner,
                          searchRemote: auth.searchUsers,
                        ),
                        2 => _historyPage(),
                        _ => _settingsPage(),
                      },
                    ),
                  ),
                ),
              ],
            ),
            extendBody: true,
            backgroundColor: Colors.transparent,
            bottomNavigationBar: _NavBar(
              selectedIndex: page,
              onSelected: (value) => setState(() => page = value),
            ),
          ),
          SosSheet(
            status: ownSos ? emergency.status : EmergencyStatus.idle,
            remaining: emergency.remaining,
            total: emergency.countdownSeconds,
            recipients: social.eligibleRecipients.map((p) => p.name).toList(),
            onCancel: () => _finishSos(cancelled: true),
            onSafe: () => _finishSos(cancelled: false),
          ),
        ],
      );
    },
  );

  Widget _avatarButton() => Semantics(
    button: true,
    label: 'Edit profile',
    child: GestureDetector(
      onTap: _openEditProfile,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.light ? Colors.white : AppColors.surface,
        ),
        child: profileAvatar(social, 18),
      ),
    ),
  );

  void _openEditProfile() {
    Navigator.of(context).push(
      SafeRoute<void>(
        builder: (_) => EditProfileScreen(
          social: social,
          safetyBannerBuilder: _routeSosBanner,
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await social.flush();
      shortcut.enable(false);
      await auth.signOut();
      social.signOut();
      await social.flush();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _stage = _AuthStage.login;
      page = 0;
    });
  }

  Future<void> _confirmSignOut() async {
    if (emergency.status != EmergencyStatus.idle) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finish or cancel the SOS first.')),
      );
      return;
    }
    final yes = await showGeneralDialog<bool>(
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
                    child: Icon(Icons.logout_rounded, color: AppColors.accent),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Sign out?',
                    style: Theme.of(dialogContext).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You will need your username or email and password to get back in.',
                    textAlign: TextAlign.center,
                    style: Theme.of(dialogContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedPill(
                          label: 'Stay',
                          onTap: () => Navigator.of(dialogContext).pop(false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: BerryButton(
                          label: 'Sign out',
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
    if (yes == true) await _signOut();
  }

  // --- Home ----------------------------------------------------------------

  Widget _homePage() {
    final recipients = social.eligibleRecipients;
    final theme = Theme.of(context);
    return HeaderPage(
      animate: false,
      headerHeight: 300,
      overlap: 38,
      lavenderTop: 150,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [const Wordmark(), _avatarButton()],
          ),
          const SizedBox(height: 22),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 290),
            child: Text(
              'Walk tall. Your circle is awake.',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontSize: 34,
                height: 1.08,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 270),
            child: Text(
              'One slide tells your trusted buddies where you are.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.light
                    ? const Color(0xFF6A3A52)
                    : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
      children: [
        SlideToSos(
          idle: emergency.status == EmergencyStatus.idle,
          onComplete: _startSos,
        ),
        const SizedBox(height: 26),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your SOS buddies',
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            GestureDetector(
              onTap: _openSosBuddies,
              child: Text(
                'Manage',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              Expanded(
                child: i < recipients.length && i < 3
                    ? _buddyTile(recipients[i].name, i)
                    : i == (recipients.length < 3 ? recipients.length : 3)
                    ? _addTile(
                        recipients.length > 3
                            ? '+${recipients.length - 3}'
                            : null,
                      )
                    : const SizedBox.shrink(),
              ),
              if (i < 3) const SizedBox(width: 10),
            ],
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _statusCard(
                'Location',
                'Ready',
                AppColors.light ? const Color(0xFFE4F2E9) : AppColors.tint,
                dot: AppColors.success,
                titleColor: AppColors.light ? const Color(0xFF3F6B52) : null,
                textColor: AppColors.light ? const Color(0xFF1E4A33) : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statusCard(
                'Buddies',
                '${recipients.length} of ${SocialController.maxSosBuddies} approved',
                AppColors.light ? const Color(0xFFEFE3F6) : AppColors.tint,
                titleColor: AppColors.light ? const Color(0xFF6B4A83) : null,
                textColor: AppColors.light ? const Color(0xFF3F2257) : null,
              ),
            ),
          ],
        ),
        if (recipients.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: _note(
              'No SOS buddies are ready. Open Buddies, add a friend, then star them in their chat menu. They must approve.',
            ),
          ),
      ],
    );
  }

  Widget _buddyTile(String name, int index) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        AvatarDot(name: name, color: avatarByIndex(index)),
        const SizedBox(height: 8),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  Widget _addTile(String? more) => Pressable(
    borderRadius: BorderRadius.circular(18),
    onTap: _openSosBuddies,
    semanticLabel: 'Add SOS buddy',
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.light ? const Color(0xFFFFEDE5) : AppColors.tint,
      ),
      foregroundDecoration: DashedBorder(
        color: AppColors.light ? const Color(0xFFD98B73) : AppColors.border,
        radius: 18,
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
            ),
            child: Text(
              more ?? '+',
              style: TextStyle(
                fontSize: more == null ? 22 : 15,
                fontWeight: FontWeight.w700,
                color: AppColors.light
                    ? const Color(0xFF8C3A1E)
                    : AppColors.text,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            more == null ? 'Add' : 'More',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.light ? const Color(0xFF8C3A1E) : AppColors.text,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _statusCard(
    String title,
    String text,
    Color bg, {
    Color? dot,
    Color? titleColor,
    Color? textColor,
  }) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      color: bg,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: titleColor ?? AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            if (dot != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
              ),
              const SizedBox(width: 7),
            ],
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textColor ?? AppColors.text,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _note(String text) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      color: AppColors.tint,
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 13, height: 1.55, color: AppColors.textMuted),
    ),
  );

  void _openSosBuddies() => Navigator.of(context).push(
    SafeRoute<void>(
      builder: (_) => SosBuddiesScreen(
        social: social,
        onAdd: () {
          Navigator.of(context).pop();
          setState(() => page = 1);
        },
      ),
    ),
  );

  // --- Activity ------------------------------------------------------------

  Widget _historyPage() {
    final events = social.visibleEvents.reversed.toList();
    return HeaderPage(
      animate: false,
      headerHeight: 190,
      overlap: 26,
      header: const HeaderTitle(
        'Activity',
        subtitle: 'Your SOS history, kept private.',
      ),
      children: [
        Row(
          children: [
            PillButton(label: 'All', filled: true),
            const SizedBox(width: 8),
            PillButton(
              label: 'SOS',
              tone: (AppColors.surface, AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final event in events)
          RowCard(
            leading: const IconChip(Icons.shield_outlined),
            title:
                '${social.person(event.senderId).name} · ${event.status.name}',
            detail:
                '${event.createdAt.toLocal().toString().substring(0, 16)} · ${event.recipientIds.map((id) => social.person(id).name).join(', ')}',
            trailing: event.lastLat == null
                ? null
                : Icon(Icons.place_rounded, color: AppColors.accent, size: 20),
          ),
        if (events.isEmpty)
          RowCard(
            leading: const IconChip(Icons.history),
            title: 'A fresh start',
            detail: 'Your SOS activity will appear here.',
          ),
        const SizedBox(height: 8),
        _note('History is not synced to an account yet.'),
      ],
    );
  }

  // --- Settings ------------------------------------------------------------

  Widget _settingsPage() {
    final theme = Theme.of(context);
    return HeaderPage(
      animate: false,
      headerHeight: 190,
      overlap: 72,
      header: const HeaderTitle('Settings'),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: profileAvatar(social, 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      social.currentUser.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '@${social.currentUser.username}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              PillButton(label: 'Edit photo', onTap: _openEditProfile),
            ],
          ),
        ),
        const SectionLabel('Appearance'),
        _Segments<ThemeMode>(
          options: const {
            ThemeMode.system: 'System',
            ThemeMode.light: 'Light',
            ThemeMode.dark: 'Dark',
          },
          selected: widget.themeMode,
          onChanged: (value) => widget.onThemeChanged?.call(value),
        ),
        const SectionLabel('Safety'),
        RowCard(
          leading: const IconChip(Icons.verified_user_outlined),
          title: 'Privacy first',
          detail: 'What is shared, and who decides',
          trailing: _chevron(),
          onTap: () => Navigator.of(
            context,
          ).push(SafeRoute<void>(builder: (_) => const PrivacyGuideScreen())),
        ),
        RowCard(
          leading: const IconChip(Icons.star_outline_rounded),
          title: 'Manage SOS buddies',
          detail:
              '${social.eligibleRecipients.length} of ${SocialController.maxSosBuddies} approved',
          trailing: _chevron(),
          onTap: _openSosBuddies,
        ),
        ListenableBuilder(
          listenable: shortcut,
          builder: (context, _) => RowCard(
            leading: const IconChip(Icons.smartphone_rounded),
            title: 'Volume key shortcut',
            detail: 'Double press to start an SOS',
            onTap: _openSosSettings,
            trailing: SoftSwitch(
              value: shortcut.enabled,
              label: 'Volume key shortcut',
              onChanged: shortcut.supported && shortcut.tested
                  ? shortcut.enable
                  : (_) => _openSosSettings(),
            ),
          ),
        ),
        RowCard(
          leading: const IconChip(Icons.logout_rounded),
          title: 'Sign out',
          onTap: _confirmSignOut,
        ),
        const SizedBox(height: 6),
        _note(
          'Messages and alerts are not delivered to other devices yet. Calling is unavailable.',
        ),
      ],
    );
  }

  /// Detail sheet behind the volume-key row: which key, testing it, how long
  /// the countdown is, and the permissions screen.
  void _openSosSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
          child: ListenableBuilder(
            listenable: emergency,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SOS settings',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 14),
                ShortcutSettings(
                  shortcut: shortcut,
                  onSelect: social.setShortcutKey,
                ),
                const SectionLabel('SOS countdown'),
                _Segments<int>(
                  options: const {3: '3 sec', 5: '5 sec', 10: '10 sec'},
                  selected: emergency.countdownSeconds,
                  onChanged: (value) {
                    emergency.countdownSeconds = value;
                    social.setCountdown(value);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 14),
                RowCard(
                  leading: const IconChip(Icons.tune_rounded),
                  title: 'Permissions',
                  detail: 'Location, camera, microphone',
                  trailing: _chevron(),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).push(
                      SafeRoute<void>(
                        builder: (_) => const PermissionsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chevron() =>
      Icon(Icons.chevron_right_rounded, color: AppColors.textMuted);
}

/// Floating bottom navigation: a solid pill in the baby pink design, glass in
/// dark. The selected destination slides its pill rather than snapping.
class _NavBar extends StatelessWidget {
  const _NavBar({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = <({IconData icon, String label})>[
    (icon: Icons.shield_outlined, label: 'Home'),
    (icon: Icons.people_outline, label: 'Buddies'),
    (icon: Icons.history, label: 'Activity'),
    (icon: Icons.settings_outlined, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final idle = AppColors.light
        ? const Color(0xFF7A5568)
        : AppColors.textMuted;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Align(
          alignment: Alignment.center,
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: GlassPanel(
              borderRadius: BorderRadius.circular(26),
              padding: EdgeInsets.zero,
              blur: 26,
              opacity: 0.70,
              child: SizedBox(
                height: 70,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (var i = 0; i < _items.length; i++)
                      Pressable(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => onSelected(i),
                        semanticLabel: _items[i].label,
                        hoverLift: 1,
                        child: AnimatedContainer(
                          duration: Motion.standard,
                          curve: Motion.enter,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: selectedIndex == i
                                ? (AppColors.light
                                      ? AppColors.secondary
                                      : AppColors.primary.withValues(
                                          alpha: 0.28,
                                        ))
                                : Colors.transparent,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _items[i].icon,
                                size: 22,
                                color: selectedIndex == i
                                    ? AppColors.onHeader
                                    : idle,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _items[i].label,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: selectedIndex == i
                                      ? AppColors.onHeader
                                      : idle,
                                ),
                              ),
                            ],
                          ),
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
}

/// A segmented control whose selected pill slides between options.
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
  Widget build(BuildContext context) {
    final keys = options.keys.toList();
    final index = keys.indexOf(selected).clamp(0, keys.length - 1);
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth / keys.length;
          return SizedBox(
            height: 42,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutBack,
                  left: w * index,
                  top: 0,
                  bottom: 0,
                  width: w,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: AppColors.light
                          ? AppColors.secondary
                          : AppColors.primary.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                Row(
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
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: AnimatedDefaultTextStyle(
                                  duration: Motion.standard,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: entry.key == selected
                                        ? AppColors.onHeader
                                        : AppColors.textMuted,
                                  ),
                                  child: Text(
                                    entry.value,
                                    maxLines: 1,
                                    softWrap: false,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
