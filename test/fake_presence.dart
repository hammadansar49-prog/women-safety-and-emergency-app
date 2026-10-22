import 'dart:async';

import 'package:safeher/presence_channel.dart';

/// Records what the app would publish, and lets a test hold a publish open
/// the way a slow network would.
class FakePresence implements PresenceChannel {
  final published = <({bool online, String? openWith, bool typing})>[];
  final watching = <String, void Function(PresenceState)>{};
  String? startedFor;
  int stops = 0;

  /// When set, an "offline" publish waits on this before completing.
  Completer<void>? holdOffline;

  @override
  Future<void> start(String uid) async => startedFor = uid;

  @override
  Future<void> publish({
    required bool online,
    String? openWith,
    required bool typing,
  }) async {
    published.add((online: online, openWith: openWith, typing: typing));
    if (!online) await holdOffline?.future;
  }

  @override
  void watch(String uid, void Function(PresenceState) onState) =>
      watching[uid] = onState;

  @override
  void unwatch(String uid) => watching.remove(uid);

  @override
  Future<void> stop() async {
    stops++;
    startedFor = null;
    watching.clear();
  }
}
