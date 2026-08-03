import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app3/main.dart';

void main() {
  testWidgets('Secure chat UI renders and accepts a new message', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Secure Chat'), findsOneWidget);
    expect(find.text('End-to-end encrypted'), findsOneWidget);
    expect(find.text('Type a message'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Hello from the test');
    await tester.tap(find.text('Send'));
    await tester.pump();

    expect(find.text('Hello from the test'), findsOneWidget);
  });
}
