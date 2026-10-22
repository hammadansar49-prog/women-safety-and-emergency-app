import 'dart:async';

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
    await stop();
    if (generation != _generation) return;
    _me = me;
    _ringSub = _signaling
        .ringingFor(me)
        .listen(
          (docs) {
            final next = [
              for (final d in docs)
                if (d.kind != CallKind.sos && active?.callId != d.id) d,
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
          },
          onError: (Object _) {},
        );
  }

  Future<void> stop() async {
    await _ringSub?.cancel();
    _ringSub = null;
    await endCall();
    await stopSos();
    ringing = const [];
    _me = null;
  }

  String _id() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
      '${(DateTime.now().millisecond * 7919).toRadixString(36)}';

  // --- Calls ---------------------------------------------------------------

  Future<void> call(String peer, CallKind kind) async {
    final me = _me;
    if (me == null || active != null) return;
    error = null;
    try {
      final s = await RtcSession.dial(
        callId: _id(),
        me: me,
        peer: peer,
        kind: kind,
        signaling: _signaling,
      );
      _adopt(s);
    } catch (e) {
      error = 'Could not start the call.';
      notifyListeners();
    }
  }

  Future<void> accept(CallDoc doc) async {
    final me = _me;
    if (me == null || active != null) return;
    _answered.add(doc.id);
    error = null;
    try {
      _adopt(await RtcSession.answer(doc: doc, me: me, signaling: _signaling));
    } catch (e) {
      error = 'Could not answer the call.';
      notifyListeners();
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
    error = null;
    try {
      final doc = await _signaling.get(callId);
      if (doc == null ||
          doc.kind != CallKind.sos ||
          doc.status != CallStatus.ringing) {
        error = 'Their live view is not available right now.';
        notifyListeners();
        return;
      }
      _adopt(await RtcSession.answer(doc: doc, me: me, signaling: _signaling));
    } catch (e) {
      error = 'Could not open the live view.';
      notifyListeners();
    }
  }

  void _adopt(RtcSession s) {
    active = s;
    s.addListener(() {
      if (s.state == RtcState.ended && active == s) {
        active = null;
        s.close();
        notifyListeners();
      } else {
        notifyListeners();
      }
    });
    notifyListeners();
  }

  Future<void> endCall() async {
    final s = active;
    active = null;
    if (s != null) {
      // Hanging up while it is still ringing on their side is a call they
      // missed, and one this chat should remember too.
      if (s.isCaller && s.kind != CallKind.sos && s.state != RtcState.connected) {
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
    if (me == null || _sosOut.isNotEmpty) return;
    try {
      await _media.invokeMethod('start');
    } catch (_) {}
    // One camera and microphone, shared by every buddy's connection.
    _sosMedia = await RtcSession.captureFor(CallKind.sos);
    for (final buddy in buddies) {
      try {
        _sosOut[buddy] = await RtcSession.dial(
          callId: '${eventId}_$buddy',
          me: me,
          peer: buddy,
          kind: CallKind.sos,
          signaling: _signaling,
          shared: _sosMedia,
        );
        // A watcher can ask this phone to flip between front and back.
        _sosOut[buddy]!.controlMessages.listen((m) {
          if (m == 'switch') _sosOut[buddy]?.switchCamera();
        });
      } catch (_) {
        // One buddy failing must not stop the others.
      }
    }
  }

  Future<void> stopSos() async {
    final sessions = _sosOut.values.toList();
    _sosOut.clear();
    for (final s in sessions) {
      await s.hangUp();
    }
    for (final t in _sosMedia?.getTracks() ?? <MediaStreamTrack>[]) {
      await t.stop();
    }
    await _sosMedia?.dispose();
    _sosMedia = null;
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
