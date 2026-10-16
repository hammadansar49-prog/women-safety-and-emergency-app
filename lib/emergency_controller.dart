import 'dart:async';
import 'package:flutter/foundation.dart';

enum EmergencyStatus { idle, countdown, active }

class EmergencyController extends ChangeNotifier {
  EmergencyStatus status = EmergencyStatus.idle;
  int remaining = 5;
  int countdownSeconds = 5;
  final List<String> history = [];
  Timer? _timer;

  void start() {
    if (status != EmergencyStatus.idle) return;
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

  void cancel() => _finish('Demo cancelled');
  void resolve() => _finish('Demo resolved');

  void _finish(String outcome) {
    if (status == EmergencyStatus.idle) return;
    _timer?.cancel();
    history.insert(0, outcome);
    status = EmergencyStatus.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
