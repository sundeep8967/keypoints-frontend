// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keypoints/main.dart';

void main() {
  testWidgets('KeyPoints app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const KeyPointsApp());

    // Verify that our app loads with the correct title
    expect(find.text('KeyPoints'), findsOneWidget);
    
    // Verify that the app shows loading or empty state initially
    expect(find.byType(CupertinoActivityIndicator), findsWidgets);
  });
}
