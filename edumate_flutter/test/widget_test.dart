import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:edumate_ai/theme/app_theme.dart';

void main() {
  testWidgets('EduMate theme renders a basic screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: Center(child: Text('EduMate AI'))),
      ),
    );
    expect(find.text('EduMate AI'), findsOneWidget);
  });
}
