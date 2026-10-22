import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'call_signaling.dart';
import 'rtc_session.dart';

/// Owns the one live call or SOS stream this phone can have at a time, and the
/// list of calls that are ringing. The screens only listen to this.
class CallController extends ChangeNotifier {
  CallController({CallSignaling? signaling})
    : _signaling = signaling ?? CallSignaling();

  final CallSignaling _signaling;

  String? _me;
  StreamSubscription<List<CallDoc>>? _ringSub;
  Timer? _ringExpiry;
  Timer? _ringRetry;

  /// Called when a call ends with nobody on it, so the chat can show it the
  /// way a phone's call log does.
  void Function(String peer, {required bool video, required bool outgoing})?
  onMissedCall;

  /// Calls this phone answered, so a ring that disappears afterwards is not
  /// mistaken for a missed one.
  final _answered = <String>{};
  List<CallDoc> _lastRinging = const [];

  /// Audio/video calls ringing for this account (SOS live views never ring).
  List<CallDoc> ringing = const [];

  /// The call this phone is in, or being a watcher of an SOS.
  RtcSession? active;

  /// Streams this phone is sending because its own SOS is running.
  final _sosOut = <String, RtcSession>{};
  MediaStream? _sosMedia;
  int _sosGeneration = 0;
  bool _startingSos = false;

  static const _media = MethodChannel('safeher/media');

  bool get inCall => active != null;

  /// The account calls are placed as, or null when nobody is signed in.
  String? get account => _me;
  String? error;

  /// Guards against an older [stop] finishing after a newer [start] and
  /// clearing the account out from under it.
  int _generation = 0;

  Future<void> start(String me) async {
    if (_me == me) return;
    final generation = ++_generation;
    await _stop();
    if (generation != _generation) return;
    _me = me;
    _listenForRings(me, generation);
    _ringExpiry = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_me != me || generation != _generation) return;
      final now = DateTime.now();
      final fresh = ringing.where((d) => d.isFreshAt(now)).toList();
      if (fresh.length == ringing.length) return;
      for (final expired in ringing.where((d) => !d.isFreshAt(now))) {
        onMissedCall?.call(
          expired.caller,
          video: expired.kind == CallKind.video,
          outgoing: false,
        );
      }
      ringing = fresh;
      _lastRinging = fresh;
      notifyListeners();
    });
  }

  void _listenForRings(String me, int generation) {
    try {
      _ringSub = _signaling.ringingFor(me).listen((docs) {
        if (_me != me || generation != _generation) return;
        if (error == 'Incoming calls disconnected. Reconnecting…') error = null;
        final now = DateTime.now();
        final next = [
          for (final d in docs)
            if (d.kind != CallKind.sos &&
                d.status == CallStatus.ringing &&
                d.isFreshAt(now) &&
                !_answered.contains(d.id) &&
                active?.callId != d.id)
              d,
        ];
        // A call that stops ringing without being answered was missed.
        final live = next.map((d) => d.id).toSet();
        for (final gone in _lastRinging) {
          if (!live.contains(gone.id) && !_answered.contains(gone.id)) {
            onMissedCall?.call(
              gone.caller,
              video: gone.kind == CallKind.video,
              outgoing: false,
            );
          }
        }
        _lastRinging = next;
        ringing = next;
        notifyListeners();
      }, onError: (Object _) => _ringingFailed(me, generation));
    } catch (_) {
      _ringingFailed(me, generation);
    }
  }

  void _ringingFailed(String me, int generation) {
    if (_me != me || generation != _generation || _disposed) return;
    error = 'Incoming calls disconnected. Reconnecting…';
    notifyListeners();
    _ringRetry?.cancel();
    _ringRetry = Timer(const Duration(seconds: 3), () async {
      if (_me != me || generation != _generation || _disposed) return;
      final old = _ringSub;
      _ringSub = null;
      await old?.cancel();
      if (_me != me || generation != _generation || _disposed) return;
      _listenForRings(me, generation);
    });
  }

  Future<void> stop() async {
    ++_generation;
    await _stop();
  }

  Future<void> _stop() async {
    _me = null;
    final sub = _ringSub;
    _ringSub = null;
    _ringRetry?.cancel();
    _ringRetry = null;
    _ringExpiry?.cancel();
    _ringExpiry = null;
    ringing = const [];
    _lastRinging = const [];
    _answered.clear();
    error = null;
    // Detach resources before awaiting cancellation: a newer sign-in may
    // start while the old subscription/native resources finish closing.
    final ending = endCall();
    final stoppingSos = stopSos();
    await sub?.cancel();
    await ending;
    await stoppingSos;
  }

  /// A call id nobody can guess. The security rules already keep outsiders
  /// out of a call, but the id travels with the signalling data, so it should
  /// not be derivable from the clock the way a timestamp is.
  static final _rand = Random.secure();
  String _id() => [
    for (var i = 0; i < 5; i++) _rand.nextInt(1 << 32).toRadixString(36),
  ].join();

  // --- Calls ---------------------------------------------------------------

  Future<void> call(String peer, CallKind kind) async {
    final me = _me;
    if (me == null || active != null) return;
    error = null;
    final s = RtcSession.outgoing(
      callId: _id(),
      me: me,
      peer: peer,
      kind: kind,
      signaling: _signaling,
    );
    _adopt(s);
    try {
      await s.startOutgoing();
    } catch (e) {
      await _setupFailed(
        s,
        'Could not start the call. Check microphone/camera permission and your connection.',
      );
    }
  }

  Future<void> accept(CallDoc doc) async {
    final me = _me;
    if (me == null ||
        active != null ||
        doc.callee != me ||
        doc.status != CallStatus.ringing ||
        !doc.isFreshAt(DateTime.now())) {
      return;
    }
    _answered.add(doc.id);
    error = null;
    final s = RtcSession.incoming(doc: doc, me: me, signaling: _signaling);
    _adopt(s);
    try {
      await s.startIncoming(doc);
    } catch (e) {
      await _setupFailed(
        s,
        'Could not answer the call. Check microphone/camera permission and your connection.',
      );
    }
  }

  Future<void> decline(CallDoc doc) async {
    try {
      await _signaling.setStatus(doc.id, CallStatus.declined);
    } catch (_) {}
  }

  /// Joins a buddy's SOS live view (watch only).
  Future<void> watchSos(String callId) async {
    final me = _me;
    if (me == null || active != null) return;
    final generation = _generation;
    error = null;
    try {
      final doc = await _signaling.get(callId);
      if (_me != me || generation != _generation || active != null) return;
      if (doc == null ||
          doc.kind != CallKind.sos ||
          doc.status != CallStatus.ringing) {
        error = 'Their live view is not available right now.';
        notifyListeners();
        return;
      }
      final s = RtcSession.incoming(doc: doc, me: me, signaling: _signaling);
      _adopt(s);
      try {
        await s.startIncoming(doc);
      } catch (_) {
        await _setupFailed(s, 'Could not open the live view.');
      }
    } catch (e) {
      if (_me != me || generation != _generation) return;
      error = 'Could not open the live view.';
      notifyListeners();
    }
  }

  void _adopt(RtcSession s) {
    active = s;
    ringing = ringing.where((doc) => doc.id != s.callId).toList();
    s.addListener(() {
      if (s.state == RtcState.ended && active == s) {
        error = s.error ?? error;
        active = null;
        s.close();
        notifyListeners();
      } else {
        notifyListeners();
      }
    });
    notifyListeners();
  }

  Future<void> _setupFailed(RtcSession s, String message) async {
    // Cancelled setup, or setup from an account that has since signed out,
    // must never reopen a call or overwrite the current account's error.
    if (active == s) {
      active = null;
      error = message;
      notifyListeners();
    }
    await s.hangUp();
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  Future<void> endCall() async {
    final s = active;
    active = null;
    if (s != null) {
      // Hanging up while it is still ringing on their side is a call they
      // missed, and one this chat should remember too.
      if (s.isCaller &&
          s.kind != CallKind.sos &&
          s.state != RtcState.connected) {
        onMissedCall?.call(
          s.peer,
          video: s.kind == CallKind.video,
          outgoing: true,
        );
      }
      await s.hangUp();
    }
    notifyListeners();
  }

  // --- My own SOS: send camera and microphone to approved buddies -----------

  /// Starts one outgoing live stream per buddy. Safe to call once per SOS.
  Future<void> startSos(String eventId, List<String> buddies) async {
    final me = _me;
    if (me == null || _sosOut.isNotEmpty || _startingSos) return;
    final generation = ++_sosGeneration;
    _startingSos = true;
    try {
      try {
        await _media.invokeMethod('start');
      } catch (_) {}
      if (generation != _sosGeneration || _me != me) return;
      // One camera and microphone, shared by every buddy's connection.
      final media = await RtcSession.captureFor(CallKind.sos);
      if (generation != _sosGeneration || _me != me) {
        for (final track in media?.getTracks() ?? <MediaStreamTrack>[]) {
          await track.stop();
        }
        await media?.dispose();
        return;
      }
      _sosMedia = media;
      for (final buddy in buddies) {
        if (generation != _sosGeneration || _me != me) return;
        try {
          final session = await RtcSession.dial(
            callId: '${eventId}_$buddy',
            me: me,
            peer: buddy,
            kind: CallKind.sos,
            signaling: _signaling,
            shared: _sosMedia,
          );
          if (generation != _sosGeneration || _me != me) {
            await session.hangUp();
            return;
          }
          _sosOut[buddy] = session;
          // A watcher can ask this phone to flip between front and back.
          _sosOut[buddy]!.controlMessages.listen((m) {
            if (m == 'switch') _sosOut[buddy]?.switchCamera();
          });
        } catch (_) {
          // One buddy failing must not stop the others.
        }
      }
    } finally {
      if (generation == _sosGeneration) _startingSos = false;
    }
  }

  Future<void> stopSos() async {
    ++_sosGeneration;
    _startingSos = false;
    final sessions = _sosOut.values.toList();
    _sosOut.clear();
    final media = _sosMedia;
    _sosMedia = null;
    for (final s in sessions) {
      await s.hangUp();
    }
    for (final t in media?.getTracks() ?? <MediaStreamTrack>[]) {
      await t.stop();
    }
    await media?.dispose();
    if (_startingSos || _sosOut.isNotEmpty || _sosMedia != null) return;
    try {
      await _media.invokeMethod('stop');
    } catch (_) {}
  }

  /// [stop] finishes after dispose returns, and whatever it tears down must
  /// not try to notify a listener that is no longer there.
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
