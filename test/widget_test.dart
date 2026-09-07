import 'package:chino/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Chino starts with the Material 3 home screen', (tester) async {
    await tester.pumpWidget(const ChinoApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.useMaterial3, isTrue);
    expect(find.text('Chino'), findsWidgets);
    expect(find.text('Import dataset'), findsOneWidget);
    expect(find.text('Open project'), findsOneWidget);
  });
}
