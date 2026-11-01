import 'dart:async';
import 'package:flutter/foundation.dart';

enum EmergencyStatus { idle, countdown, active }

class EmergencyController extends ChangeNotifier {
  EmergencyStatus status = EmergencyStatus.idle;
  int remaining = 5;
  int countdownSeconds = 5;
  final List<String> history = [];
  Timer? _timer;

  /// A silent SOS goes live at once and is kept off the screen.
  bool silent = false;

  void start({bool silent = false}) {
    if (status != EmergencyStatus.idle) return;
    this.silent = silent;
    if (silent) {
      status = EmergencyStatus.active;
      notifyListeners();
      return;
    }
    remaining = countdownSeconds;
    status = EmergencyStatus.countdown;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    notifyListeners();
  }

  void tick() {
    if (status != EmergencyStatus.countdown) return;
    remaining--;
    if (remaining <= 0) {
      _timer?.cancel();
      status = EmergencyStatus.active;
    }
    notifyListeners();
  }

  void cancel() => _finish('SOS cancelled');
  void resolve() => _finish('SOS resolved');

  void _finish(String outcome) {
    if (status == EmergencyStatus.idle) return;
    _timer?.cancel();
    history.insert(0, outcome);
    silent = false;
    status = EmergencyStatus.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
