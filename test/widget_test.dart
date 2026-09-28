import 'package:flutter_test/flutter_test.dart';

import 'package:trackie/main.dart';

void main() {
  testWidgets('App renders login page correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TrackieApp());

    // Verify that the title text is found.
    expect(find.text('Trackie.'), findsOneWidget);
  });
}
