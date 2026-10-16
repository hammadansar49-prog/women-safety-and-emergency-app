import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/emergency_controller.dart';

void main() {
  test('duplicate activation preserves a single countdown', () {
    final state = EmergencyController();
    state.start();
    state.tick();
    state.start();
    expect(state.remaining, 4);
    state.dispose();
  });
  test('cancellation prevents countdown becoming active', () {
    final state = EmergencyController();
    state.start();
    state.cancel();
    for (var i = 0; i < 6; i++) {
      state.tick();
    }
    expect(state.status, EmergencyStatus.idle);
    expect(state.history.single, 'Demo cancelled');
    state.dispose();
  });
  test('countdown activates and resolution records the result', () {
    final state = EmergencyController();
    state.start();
    for (var i = 0; i < 5; i++) {
      state.tick();
    }
    expect(state.status, EmergencyStatus.active);
    state.resolve();
    expect(state.status, EmergencyStatus.idle);
    expect(state.history.single, 'Demo resolved');
    state.dispose();
  });
}
