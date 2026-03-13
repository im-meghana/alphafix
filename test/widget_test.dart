import 'package:flutter_test/flutter_test.dart';
import 'package:alphafix/main.dart';

void main() {
  testWidgets('AlphaFix app builds', (WidgetTester tester) async {
    await tester.pumpWidget(const AlphaFixApp());
    expect(find.byType(AlphaFixApp), findsOneWidget);
  });
}