import 'package:flutter_test/flutter_test.dart';
import 'package:engazz/app.dart';
import 'package:engazz/painters/ring_painter.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Timer starts and border animation value decreases', (WidgetTester tester) async {
    await tester.pumpWidget(const EngazzApp());

    // Initially, find RingPainter
    CustomPaint customPaint = tester.widget(find.byType(CustomPaint).first);
    RingPainter painter = customPaint.painter as RingPainter;
    expect(painter.animation.value, equals(1.0));

    // Tap on SEC (increment seconds to 2)
    await tester.tap(find.text('SEC'));
    await tester.pump();
    await tester.tap(find.text('SEC'));
    await tester.pump();

    // Tap Start
    await tester.tap(find.text('Start'));
    await tester.pump();

    // Advance by 1500ms (1.5s of 2s)
    await tester.pump(const Duration(milliseconds: 1500));

    customPaint = tester.widget(find.byType(CustomPaint).first);
    painter = customPaint.painter as RingPainter;

    // Animation value should now be ~0.5, decreasing from 1.0!
    expect(painter.animation.value, lessThan(1.0));
    expect(painter.animation.value, greaterThan(0.0));
    expect(painter.full, isFalse);

    // Tap End
    await tester.tap(find.text('End'));
    await tester.pump();

    // Verify clock is reset to zero (00)
    expect(find.text('00'), findsNWidgets(3)); // HOUR, MIN, SEC all 00
    customPaint = tester.widget(find.byType(CustomPaint).first);
    painter = customPaint.painter as RingPainter;
    expect(painter.animation.value, equals(1.0));

    // Verify session was added
    expect(find.text('الأولى'), findsOneWidget);

    // Tap delete button to open dialog
    await tester.tap(find.byIcon(Icons.delete_rounded));
    await tester.pumpAndSettle();

    // Dialog should be visible
    expect(find.text('هل أنت متأكد من مسح جميع الجلسات؟'), findsOneWidget);

    // Tap "مسح"
    await tester.tap(find.text('مسح'));
    await tester.pumpAndSettle();

    // Verify sessions are cleared
    expect(find.text('الأولى'), findsNothing);
  });
}
