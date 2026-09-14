import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_app/widgets/virtual_joystick_widget.dart';

void main() {
  testWidgets('VirtualJoystick widget renders correctly', (WidgetTester tester) async {
    Offset changedDir = Offset.zero;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: VirtualJoystick(
              size: 120,
              onDirectionChanged: (dir) {
                changedDir = dir;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.byType(VirtualJoystick), findsOneWidget);
    expect(changedDir, equals(Offset.zero));
  });
}
