import 'package:flutter_test/flutter_test.dart';
import 'package:md_television/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MDTelevisionApp());
    expect(find.byType(MDTelevisionApp), findsOneWidget);
  });
}
