import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wing_trace/main.dart'; // Imports WingTraceApp

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // 1. Build our app and trigger a frame.
    // CHANGED: MyApp -> WingTraceApp
    await tester.pumpWidget(const WingTraceApp());

    // 2. Verify that the Splash Screen appears.
    // The default test looked for '0', but your app shows 'WingTrace'
    expect(find.text('WingTrace'), findsOneWidget);
    
    // Verify the loading text is present
    expect(find.text('loading app'), findsOneWidget);
  });
}