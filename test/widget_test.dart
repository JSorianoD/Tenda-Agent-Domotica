import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jarvis_mockup/main.dart';

void main() {
  testWidgets('App renders home screen when already logged in',
      (WidgetTester tester) async {
    // Pass '/' directly to skip the auth check in this unit test.
    await tester.pumpWidget(const ProviderScope(child: JarvisApp()));
    await tester.pumpAndSettle();

    expect(find.text('EN ESPERA'), findsOneWidget);
  });
}
