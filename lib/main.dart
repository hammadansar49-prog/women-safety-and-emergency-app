import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'package:url_launcher/url_launcher.dart';

import 'ui/design.dart';
import 'ui/sos_map_card.dart';
import 'ui/sos_slider.dart';
import 'profile_screen.dart';
import 'sos_buddies_screen.dart';
import 'permissions_screen.dart';
import 'security_screens.dart';
import 'onboarding_guide.dart';
import 'alert_sounder.dart';
import 'call_controller.dart';
import 'call_signaling.dart';
import 'call_screens.dart';
import 'cloud_backup.dart';
import 'e2e_hook.dart';
import 'username_check.dart';
import 'cloud_social.dart';
import 'e2ee.dart';
import 'backup_screens.dart';
import 'incoming_sos_screen.dart';

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
    final loaded = await loadLocalAccount();
    final social = loaded.social;
    final vault = loaded.vault;
    // Reopen the account that was signed in, with only its own data. If the
    // cloud session is gone, the device starts signed out instead.
    final last = vault.session;
    if (last != null) {
      final cloudGone =
          Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser == null;
      final saved = vault.account(last);
      if (cloudGone || saved == null) {
        await vault.setSession(null);
      } else {
        social.enterAccount(last, saved, name: '');
      }
    }
    final previewScreen = localPreview
        ? Uri.base.queryParameters['screen']
        : null;
    if (localPreview &&
        !social.signedIn &&
        previewScreen != 'login' &&
        previewScreen != 'register') {
      social.enterAccount(
        'tester_one',
        vault.account('tester_one'),
        name: 'Tester',
        username: previewScreen == 'username' ? '' : 'tester_one',
      );
      social.setSignedIn(true);
      if (previewScreen != 'guide') social.markGuideSeen();
      social.seedDemoFriend('ayesha');
      social.seedDemoSosBuddy('ayesha');
    }
    try {
      await recoverProfilePhoto(social);
    } catch (_) {
      social.saveError =
          'Could not recover the selected photo. Please choose it again.';
    }
    runApp(SafeHerApp(social: social, vault: vault));
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
  const SafeHerApp({super.key, this.social, this.vault});
  final SocialController? social;
  final LocalVault? vault;
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

  /// Owned here, above the Navigator, so a ringing or running call covers
  /// whatever screen is open — including a chat pushed on top of the shell.
  final calls = CallController();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    calls.dispose();
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
        builder: (context, child) => AuroraBackground(
          child: Stack(
            children: [
              child ?? const SizedBox.shrink(),
              CallOverlay(calls: calls, social: social),
            ],
          ),
        ),
        home: SafeHerShell(
          social: social,
          calls: calls,
          vault: widget.vault,
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
    this.vault,
    this.calls,
  });
  final LocalVault? vault;
  final AuthService? auth;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeChanged;
  final SocialController? social;

  /// Supplied by the app so the call overlay can live above the Navigator.
  /// Left out in tests, where the shell makes its own.
  final CallController? calls;
  @override
  State<SafeHerShell> createState() => _SafeHerShellState();
}

/// The auth surface shown before the user reaches the app.
enum _AuthStage { welcome, login, register }

class _SafeHerShellState extends State<SafeHerShell>
    with WidgetsBindingObserver {
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

  // --- Cloud backup --------------------------------------------------------
  CloudBackup? _backup;
  String? _backupChecked; // uid whose backup state was settled this run
  String? _recoveryCode; // shown once, right after backup is turned on
  bool _needsRestore = false;
  Timer? _backupTimer;
  CloudSocial? _cloud;

  /// The app owns this so the call overlay sits above every pushed route; a
  /// shell built on its own (tests) falls back to one of its own.
  late final CallController calls = widget.calls ?? CallController();
  bool get _ownsCalls => widget.calls == null;
  final _sounder = AlertSounder();

  /// SOS alerts from other people that this phone has already shouted about.
  final _announced = <String>{};

  /// An SOS from a buddy makes this phone loud: a siren plus a spoken line,
  /// so it can be heard from a pocket. It stops when every alert has ended.
  void _soundIncomingAlerts() {
    final live = social.visibleEvents.where(
      (e) =>
          e.senderId != social.currentUserId &&
          e.status == LocalSosStatus.active,
    );
    if (live.isEmpty) {
      _announced.clear();
      if (_sounder.isOn) _sounder.stop();
      return;
    }
    final fresh = live.where((e) => !_announced.contains(e.id)).toList();
    if (fresh.isEmpty) return;
    for (final e in live) {
      _announced.add(e.id);
    }
    _sounder.siren(social.person(fresh.first.senderId).name);
  }

  late final UsernameChecker _usernameChecker;

  /// Starts friends, requests and encrypted chat for the signed-in account.
  /// Runs only once the backup question is settled, so the chat identity that
  /// gets published is the one the account will keep.
  void _startCloud() {
    final uid = _backupUid;
    final name = social.currentUser.username;
    if (uid == null || name.isEmpty) return;
    _cloud ??= CloudSocial(social, onError: social.setSyncError);
    _cloud!.start(name, uid);
    social.onChatOpen = _cloud!.setOpenChat;
    calls.start(name);
  }

  String? get _backupUid => _backup == null ? null : auth.uid;

  /// Decides, once per sign-in, whether to turn backup on, ask for the
  /// recovery code (the account already has a backup this phone lacks), or
  /// simply keep the existing backup current.
  Future<void> _settleBackup() async {
    final uid = _backupUid;
    final vault = widget.vault;
    if (uid == null || vault == null || _backupChecked == uid) return;
    _backupChecked = uid;
    try {
      if (vault.backupKey(uid) != null) {
        _startCloud();
        return;
      }
      if (await _backup!.exists(uid)) {
        if (mounted) setState(() => _needsRestore = true);
        return;
      }
      // The chat identity has to exist before the backup is sealed, so the
      // backup carries it.
      if (social.identityPriv == null) {
        final id = await const E2ee().newIdentity();
        social.setIdentity(id.priv, id.pub);
      }
      final enabled = await _backup!.enable(uid, social.snapshot());
      await vault.setBackupKey(uid, enabled.keyB64);
      _startCloud();
      if (mounted) setState(() => _recoveryCode = enabled.recoveryCode);
    } catch (_) {
      _backupChecked = null; // offline or rules: try again next change
    }
  }

  void _scheduleBackupSave() {
    final uid = _backupUid;
    final key = uid == null ? null : widget.vault?.backupKey(uid);
    if (uid == null || key == null || social.accountKey == null) return;
    _backupTimer?.cancel();
    _backupTimer = Timer(const Duration(seconds: 4), () => _saveBackup());
  }

  Future<void> _saveBackup() async {
    final uid = _backupUid;
    final key = uid == null ? null : widget.vault?.backupKey(uid);
    if (uid == null || key == null || social.accountKey == null) return;
    try {
      await _backup!.save(uid, key, social.snapshot());
    } catch (_) {}
  }

  Future<String?> _restoreBackup(String code) async {
    final uid = _backupUid;
    if (uid == null) return 'Not signed in.';
    try {
      final restored = await _backup!.restore(uid, code);
      final username = social.accountKey ?? '';
      await widget.vault?.setBackupKey(uid, restored.keyB64);
      social.enterAccount(
        username,
        restored.snapshot,
        name: '',
        username: username,
      );
      social.setSignedIn(true);
      if (mounted) setState(() => _needsRestore = false);
      _startCloud();
      return null;
    } on BackupFailure catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not reach the backup. Check your connection.';
    }
  }

  Future<void> _startOverBackup() async {
    final uid = _backupUid;
    if (uid == null) return;
    try {
      await _backup!.reset(uid);
      _backupChecked = null;
      await widget.vault?.setBackupKey(uid, null);
      if (mounted) setState(() => _needsRestore = false);
      await _settleBackup();
    } catch (_) {}
  }

  /// Test-only entry points for the web end-to-end build. The whole body is
  /// dead code unless the app is compiled with SAFEHER_E2E=true.
  Future<Object?> _e2e(String name, List<dynamic> a) async {
    switch (name) {
      case 'register':
        return await _handleRegister(a[0], a[1], a[2], a[3]) ?? 'ok';
      case 'login':
        return await _handleLogin(a[0], a[1]) ?? 'ok';
      case 'signOut':
        await _signOut();
        return social.signedIn ? 'still signed in' : 'ok';
      case 'restore':
        return await _restoreBackup(a[0]) ?? 'ok';
      case 'continue':
        // Past the recovery code and the guide.
        final code = _recoveryCode;
        _recoveryCode = null;
        social.markGuideSeen();
        if (mounted) setState(() {});
        return code;
      case 'search':
        return [for (final r in await auth.searchUsers(a[0])) r.username];
      case 'addBuddy':
        social.adoptRemote(a[0], a[0]);
        social.requestFriend(a[0]);
        return 'ok';
      case 'respond':
        final r = social.pendingIncoming.firstWhere((r) => r.fromId == a[0]);
        social.respondToFriendRequest(r.id, a[1] == true);
        return 'ok';
      case 'favorite':
        social.favorite(a[0]);
        return 'ok';
      case 'sosAnswer':
        social.respondToSosRequest(a[0], a[1] == true);
        return 'ok';
      case 'send':
        social.sendMessage(a[0], a[1]);
        return 'ok';
      case 'sosStart':
        return social.createSos().id;
      case 'sosMove':
        final id = social.visibleEvents
            .firstWhere(
              (e) =>
                  e.senderId == social.currentUserId &&
                  e.status == LocalSosStatus.active,
            )
            .id;
        social.updateSosLocation(
          id,
          (a[0] as num).toDouble(),
          (a[1] as num).toDouble(),
          DateTime.now(),
        );
        return id;
      case 'sosEnd':
        final id = social.visibleEvents
            .firstWhere(
              (e) =>
                  e.senderId == social.currentUserId &&
                  e.status == LocalSosStatus.active,
            )
            .id;
        social.finishSos(id, cancelled: false);
        return id;
      case 'callStart':
        await calls.call(
          a[0] as String,
          a[1] == 'video' ? CallKind.video : CallKind.audio,
        );
        return calls.error ?? 'ok';
      case 'callAccept':
        if (calls.ringing.isEmpty) return 'nothing ringing';
        await calls.accept(calls.ringing.first);
        return calls.error ?? 'ok';
      case 'callDecline':
        if (calls.ringing.isEmpty) return 'nothing ringing';
        await calls.decline(calls.ringing.first);
        return 'ok';
      case 'callEnd':
        await calls.endCall();
        return 'ok';
      case 'watchSos':
        await calls.watchSos(a[0] as String);
        return calls.error ?? 'ok';
      case 'callState':
        final s = calls.active;
        return {
          'ringing': [
            for (final r in calls.ringing)
              {'id': r.id, 'from': r.caller, 'kind': r.kind.name},
          ],
          'active': s == null
              ? null
              : {
                  'id': s.callId,
                  'peer': s.peer,
                  'kind': s.kind.name,
                  'state': s.state.name,
                  'caller': s.isCaller,
                  'hasRemote': s.remote != null,
                  'remoteVideo': s.remote?.getVideoTracks().isNotEmpty ?? false,
                  'remoteAudio': s.remote?.getAudioTracks().isNotEmpty ?? false,
                  'localVideo': s.local?.getVideoTracks().isNotEmpty ?? false,
                },
          'error': calls.error,
        };
      case 'state':
        return {
          'me': social.currentUser.username,
          'name': social.currentUser.name,
          'signedIn': social.signedIn,
          'needsRestore': _needsRestore,
          'recoveryCode': _recoveryCode,
          'syncError': social.syncError,
          'hasIdentity': social.identityPub != null,
          'friends': [for (final f in social.friends) f.id],
          'incoming': [for (final r in social.pendingIncoming) r.fromId],
          'outgoing': [for (final r in social.pendingOutgoing) r.toId],
          'sosApproved': [for (final p in social.eligibleRecipients) p.id],
          'sosAsks': [for (final r in social.incomingSosRequests) r.senderId],
          'chats': {
            for (final f in social.friends)
              f.id: [
                for (final m in social.messagesWith(f.id))
                  '${m.senderId == social.currentUserId ? 'me' : m.senderId}: ${m.text}',
              ],
          },
          'alerts': [
            for (final e in social.visibleEvents)
              {
                'id': e.id,
                'from': e.senderId,
                'status': e.status.name,
                'lat': e.lastLat,
                'lng': e.lastLng,
              },
          ],
        };
    }
    return 'unknown call $name';
  }

  @override
  void initState() {
    super.initState();
    if (const bool.fromEnvironment('SAFEHER_E2E')) installE2eHook(_e2e);
    social = widget.social ?? SocialController(newAccount: true);
    auth =
        widget.auth ??
        (Firebase.apps.isNotEmpty
            ? FirebaseAuthService()
            : LocalAuthService(
                saved: widget.vault?.authData,
                onChanged: widget.vault?.saveAuthData,
              ));
    if (Firebase.apps.isNotEmpty && auth is FirebaseAuthService) {
      _backup = CloudBackup(FirestoreBackupStore());
    }
    _usernameChecker = UsernameChecker(
      quick: auth.quickUsernameCheck,
      confirm: auth.usernameAvailable,
    );
    calls.onMissedCall = (peer, {required video, required outgoing}) =>
        social.noteMissedCall(peer, video: video, outgoing: outgoing);
    social.addListener(_syncSession);
    social.addListener(_soundIncomingAlerts);
    WidgetsBinding.instance.addObserver(this);
    // Reopening into an account with a PIN starts locked.
    _locked = social.signedIn && social.hasPin;
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
      case 'forgot':
        Navigator.of(context).push(
          SafeRoute<void>(
            builder: (_) => ForgotPasswordScreen(onSend: (_) async => null),
          ),
        );
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
      case 'guide':
        break;
      case 'lock':
        setState(() => _locked = true);
      case 'pin':
        Navigator.of(context).push(
          SafeRoute<void>(
            builder: (_) =>
                PinSetupScreen(social: social, mode: PinMode.create),
          ),
        );
      case 'privacy':
        Navigator.of(
          context,
        ).push(SafeRoute<void>(builder: (_) => const PrivacyGuideScreen()));
    }
  }

  bool _locked = false;
  DateTime? _pausedAt;

  /// Locks again after the app has been away for a while. Short trips (a
  /// permission dialog, the dialer) do not lock.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      // Buddies should see "last seen", not an account that is still online.
      _cloud?.goAway();
    } else if (state == AppLifecycleState.resumed) {
      _cloud?.setOpenChat(null);
      final away = _pausedAt;
      _pausedAt = null;
      if (away != null &&
          social.signedIn &&
          social.hasPin &&
          DateTime.now().difference(away) > const Duration(seconds: 45) &&
          mounted) {
        setState(() => _locked = true);
      }
    }
  }

  String? _savedSession;

  /// Remembers which account is signed in (or none), so a restart reopens only
  /// that account.
  void _syncSession() {
    final vault = widget.vault;
    if (vault == null) return;
    final key = social.signedIn && social.currentUser.username.isNotEmpty
        ? social.accountKey
        : null;
    if (key != null) {
      _settleBackup();
      _scheduleBackupSave();
    }
    if (key == _savedSession) return;
    _savedSession = key;
    vault.setSession(key);
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
    String fullName,
  ) async {
    try {
      final name = await auth.register(
        email: email,
        username: username,
        password: password,
        name: fullName,
      );
      _enter(name, fresh: true, fullName: fullName);
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

  Future<String?> _handleForgot(String email) async {
    try {
      await auth.sendPasswordReset(email);
      return null;
    } on AuthFailure catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not send the link. Try again.';
    }
  }

  /// Opens [username]'s own data and nobody else's. A brand new account
  /// ([fresh]) always starts blank.
  void _enter(String username, {bool fresh = false, String fullName = ''}) {
    final name = fullName.isNotEmpty ? fullName : (auth.displayName ?? '');
    if (username.isEmpty) {
      social.enterUnnamedAccount(name: name);
    } else {
      social.enterAccount(
        username,
        fresh ? null : widget.vault?.account(username),
        name: name,
        username: username,
      );
    }
    // Local preview mode has nobody to talk to, so seed one demo buddy.
    if (auth is LocalAuthService) social.seedDemoFriend('ayesha');
    social.setSignedIn(true);
    if (mounted) setState(() {});
  }

  Widget _storageStatus() {
    if (social.syncError != null && social.saveError == null) {
      return Material(
        color: Theme.of(context).colorScheme.errorContainer,
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.cloud_off_outlined),
          title: Text(social.syncError!),
        ),
      );
    }
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
        // Camera and microphone go to the approved buddies, alongside the
        // location stream.
        if (social.cloudConnected) {
          calls.startSos(
            activeEventId!,
            social.eligibleRecipients.map((p) => p.id).toList(),
          );
        }
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
      calls.stopSos();
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
    social.removeListener(_syncSession);
    social.removeListener(_soundIncomingAlerts);
    _sounder.dispose();
    if (_ownsCalls) calls.dispose();
    _backupTimer?.cancel();
    _usernameChecker.dispose();
    WidgetsBinding.instance.removeObserver(this);
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
              onForgotPassword: _handleForgot,
              onCreateAccount: () =>
                  setState(() => _stage = _AuthStage.register),
            );
          case _AuthStage.register:
            return RegisterScreen(
              onRegister: _handleRegister,
              checker: _usernameChecker,
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
          checker: _usernameChecker,
        );
      }
      if (_needsRestore) {
        return RestoreBackupScreen(
          onRestore: _restoreBackup,
          onStartOver: _startOverBackup,
        );
      }
      if (_recoveryCode != null) {
        return RecoveryCodeScreen(
          code: _recoveryCode!,
          onDone: () => setState(() => _recoveryCode = null),
        );
      }
      if (!social.guideSeen) {
        return OnboardingGuide(onDone: social.markGuideSeen);
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
                    color: AppColors.danger,
                    child: SafeArea(
                      bottom: false,
                      child: ListTile(
                        textColor: Colors.white,
                        iconColor: Colors.white,
                        leading: const Icon(Icons.sos),
                        title: Text(
                          'SOS from ${social.person(event.senderId).name}',
                        ),
                        subtitle: Text(
                          event.lastLat == null
                              ? 'Waiting for their location…'
                              : 'Live location available',
                        ),
                        trailing: TextButton(
                          onPressed: () {
                            _sounder.stop();
                            Navigator.of(context).push(
                              SafeRoute<void>(
                                builder: (_) => IncomingSosScreen(
                                  social: social,
                                  eventId: event.id,
                                  calls: calls,
                                ),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
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
                          calls: calls,
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
          // The app draws the call overlay above the Navigator; a shell on
          // its own (tests) still needs one here.
          if (_ownsCalls) CallOverlay(calls: calls, social: social),
          if (_locked)
            PinLockScreen(
              social: social,
              onUnlocked: () => setState(() => _locked = false),
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
      _backupTimer?.cancel();
      // Last backup and cloud shutdown must not be able to trap the person
      // inside the app if the network is slow.
      await _saveBackup().timeout(const Duration(seconds: 6), onTimeout: () {});
      await _cloud?.stop().timeout(
        const Duration(seconds: 3),
        onTimeout: () {},
      );
      await calls.stop().timeout(const Duration(seconds: 3), onTimeout: () {});
      await _sounder.stop();
      _announced.clear();
      social.setSyncError(null);
      shortcut.enable(false);
      await auth.signOut();
      _backupChecked = null;
      _recoveryCode = null;
      _needsRestore = false;
      social.signOut();
      await social.flush();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not sign out: $e')));
      }
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
      // The headline shrinks rather than spilling out of the header when the
      // device text size is large or the screen is short.
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [const Wordmark(), _avatarButton()],
          ),
          const SizedBox(height: 22),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 290),
                child: Text(
                  'Walk tall. Your circle is awake.',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontSize: 34,
                    height: 1.08,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
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
            ),
          ),
        ],
      ),
      children: [
        SlideToSos(
          idle: emergency.status == EmergencyStatus.idle,
          ready: social.eligibleRecipients.isNotEmpty,
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
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            // An SOS that reached a place gets the map; one cancelled in the
            // countdown never had a location, so it stays a plain row.
            child: event.lastLat == null
                ? RowCard(
                    leading: const IconChip(Icons.shield_outlined),
                    title: _sosTitle(event),
                    detail: _sosDetail(event),
                  )
                : SosMapCard(
                    title: event.status == LocalSosStatus.active
                        ? _sosTitle(event)
                        : 'SOS ended here',
                    detail: _sosDetail(event),
                    badge: switch (event.status) {
                      LocalSosStatus.active => 'Live',
                      LocalSosStatus.cancelled => 'Cancelled',
                      LocalSosStatus.resolved => 'Resolved',
                    },
                    resolved: event.status == LocalSosStatus.resolved,
                    onTap: () => launchUrl(
                      Uri.parse(
                        'https://www.google.com/maps/search/?api=1&query='
                        '${event.lastLat},${event.lastLng}',
                      ),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
          ),
        if (events.isEmpty)
          RowCard(
            leading: const IconChip(Icons.history),
            title: 'A fresh start',
            detail: 'Your SOS activity will appear here.',
          ),
      ],
    );
  }

  /// "You raised an SOS" reads better than your own username echoed back.
  String _sosTitle(LocalSosEvent e) => e.senderId == social.currentUserId
      ? 'Your SOS'
      : '${social.person(e.senderId).name} raised an SOS';

  String _sosDetail(LocalSosEvent e) {
    final when = _whenLabel(e.createdAt.toLocal());
    final parts = <String>[when];
    final ended = e.endedAt;
    if (ended != null) {
      final mins = ended.difference(e.createdAt).inMinutes;
      parts.add(mins < 1 ? 'under a minute' : '$mins min');
    }
    if (e.status == LocalSosStatus.cancelled) {
      parts.add('cancelled in countdown');
    } else if (e.recipientIds.isNotEmpty) {
      final n = e.recipientIds.length;
      parts.add('shared with $n ${n == 1 ? 'buddy' : 'buddies'}');
    }
    return parts.join(' · ');
  }

  /// "Today, 8:12 pm", "Yesterday, 6:40 pm", else "Mon, 5:02 pm".
  String _whenLabel(DateTime t) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    final sameDay =
        t.year == now.year && t.month == now.month && t.day == now.day;
    final y = now.subtract(const Duration(days: 1));
    final yesterday = t.year == y.year && t.month == y.month && t.day == y.day;
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final clock =
        '$hour:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'am' : 'pm'}';
    final day = sameDay
        ? 'Today'
        : yesterday
        ? 'Yesterday'
        : days[t.weekday - 1];
    return '$day, $clock';
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
          leading: const IconChip(Icons.lock_outline_rounded),
          title: 'App PIN lock',
          detail: social.hasPin
              ? 'On. Asked when SafeHer opens'
              : 'Ask for a PIN when SafeHer opens',
          onTap: () => Navigator.of(context).push(
            SafeRoute<void>(
              builder: (_) => PinSetupScreen(
                social: social,
                mode: social.hasPin ? PinMode.disable : PinMode.create,
              ),
            ),
          ),
          trailing: SoftSwitch(
            value: social.hasPin,
            label: 'App PIN lock',
            onChanged: (_) => Navigator.of(context).push(
              SafeRoute<void>(
                builder: (_) => PinSetupScreen(
                  social: social,
                  mode: social.hasPin ? PinMode.disable : PinMode.create,
                ),
              ),
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
          'Chats are end-to-end encrypted. SOS alerts, your live location, and '
              'voice and video calls go straight to your approved buddies.',
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

  static const _items = <({int glyph, String label})>[
    (glyph: 0, label: 'Home'),
    (glyph: 1, label: 'Buddies'),
    (glyph: 2, label: 'Activity'),
    (glyph: 3, label: 'Settings'),
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
              opacity: AppColors.light ? 1 : 0.70,
              child: SizedBox(
                height: 72,
                // Each tab takes an equal share, so four of them still fit on
                // a narrow phone or at a large text size.
                child: Row(
                  children: [
                    for (var i = 0; i < _items.length; i++)
                      Expanded(
                        child: Pressable(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => onSelected(i),
                          semanticLabel: _items[i].label,
                          hoverLift: 1,
                          child: AnimatedContainer(
                            duration: Motion.standard,
                            curve: Motion.enter,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: selectedIndex == i
                                  ? (AppColors.light
                                        ? AppColors.header
                                        : AppColors.primary.withValues(
                                            alpha: 0.28,
                                          ))
                                  : Colors.transparent,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CustomPaint(
                                  size: const Size(22, 22),
                                  painter: _NavGlyph(
                                    _items[i].glyph,
                                    selectedIndex == i
                                        ? AppColors.onHeader
                                        : idle,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _items[i].label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
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

/// The design's nav icons (24-unit stroke glyphs), drawn directly so they
/// match the artboards rather than the nearest Material icon.
class _NavGlyph extends CustomPainter {
  const _NavGlyph(this.glyph, this.color);
  final int glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    canvas.scale(k);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final path = Path();
    switch (glyph) {
      case 0:
        path
          ..moveTo(12, 3)
          ..relativeLineTo(8, 3)
          ..relativeLineTo(0, 6)
          ..relativeCubicTo(0, 5, -3.5, 8, -8, 9)
          ..relativeCubicTo(-4.5, -1, -8, -4, -8, -9)
          ..lineTo(4, 6)
          ..close();
      case 1:
        path
          ..addOval(Rect.fromCircle(center: const Offset(9, 8), radius: 3.5))
          ..moveTo(2.5, 20)
          ..relativeCubicTo(0, -3.5, 3, -6, 6.5, -6)
          ..relativeCubicTo(3.5, 0, 6.5, 2.5, 6.5, 6)
          ..moveTo(16, 4.5)
          ..arcToPoint(
            const Offset(16, 11.5),
            radius: const Radius.circular(3.5),
          )
          ..moveTo(18, 14)
          ..relativeCubicTo(2.2, 0.6, 3.5, 2.6, 3.5, 6);
      case 2:
        path
          ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 9))
          ..moveTo(12, 7)
          ..relativeLineTo(0, 5)
          ..relativeLineTo(3, 2);
      default:
        path
          ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 3))
          ..moveTo(12, 2)
          ..relativeLineTo(0, 3)
          ..moveTo(12, 19)
          ..relativeLineTo(0, 3)
          ..moveTo(2, 12)
          ..relativeLineTo(3, 0)
          ..moveTo(19, 12)
          ..relativeLineTo(3, 0)
          ..moveTo(4.9, 4.9)
          ..relativeLineTo(2.1, 2.1)
          ..moveTo(17, 17)
          ..relativeLineTo(2.1, 2.1)
          ..moveTo(4.9, 19.1)
          ..lineTo(7, 17)
          ..moveTo(17, 7)
          ..relativeLineTo(2.1, -2.1);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_NavGlyph old) => old.glyph != glyph || old.color != color;
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
