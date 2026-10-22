import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/ui/chat_composer.dart';

void main() {
  Widget waveform(List<double> levels, int sample, {bool reduceMotion = false}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Center(
          child: SizedBox(
            width: 240,
            height: 34,
            child: RecordingWaveform(
              levels: levels,
              sampleTime: Duration(milliseconds: sample * 120),
              color: Colors.purple,
            ),
          ),
        ),
      ),
    );
  }

  Finder painting() => find.descendant(
    of: find.byType(RecordingWaveform),
    matching: find.byType(CustomPaint),
  );

  testWidgets('microphone samples keep painting between input ticks', (
    tester,
  ) async {
    // The recorder mutates one bounded list in place on every reading.
    final levels = <double>[0.1, 0.7, 0.2];
    await tester.pumpWidget(waveform(levels, 1));
    levels.add(0.9);
    await tester.pumpWidget(waveform(levels, 2));
    final painter = tester.widget<CustomPaint>(painting()).painter!;
    var repaints = 0;
    void onRepaint() => repaints++;
    painter.addListener(onRepaint);

    await tester.pump(const Duration(milliseconds: 16));
    final firstFrame = repaints;
    await tester.pump(const Duration(milliseconds: 16));
    expect(firstFrame, greaterThan(0));
    expect(repaints, greaterThan(firstFrame));
    // Frame ticks paint only; they must not rebuild the composer/painter.
    expect(tester.widget<CustomPaint>(painting()).painter, same(painter));
    expect(
      find.ancestor(of: painting(), matching: find.byType(RepaintBoundary)),
      findsWidgets,
    );

    painter.removeListener(onRepaint);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion displays samples without frame animation', (
    tester,
  ) async {
    await tester.pumpWidget(waveform([0.1, 0.7], 1));
    await tester.pumpWidget(waveform([0.1, 0.7, 0.9], 2));
    await tester.pump(const Duration(milliseconds: 16));
    // Changing this preference while moving must stop the current animation.
    await tester.pumpWidget(
      waveform([0.1, 0.7, 0.9], 2, reduceMotion: true),
    );
    final painter = tester.widget<CustomPaint>(painting()).painter!;
    var repaints = 0;
    void onRepaint() => repaints++;
    painter.addListener(onRepaint);
    await tester.pump(const Duration(milliseconds: 32));
    expect(repaints, 0);
    expect(tester.binding.transientCallbackCount, 0);
    painter.removeListener(onRepaint);
  });

  testWidgets('silent and full bounded buffers stay safe on narrow layouts', (
    tester,
  ) async {
    await tester.pumpWidget(waveform([], 0));
    for (var sample = 1; sample <= 55; sample++) {
      await tester.pumpWidget(
        waveform(List<double>.generate(48, (i) => (i % 10) / 10), sample),
      );
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.binding.transientCallbackCount, 0);
  });
}
