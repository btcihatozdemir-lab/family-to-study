import 'package:flutter_test/flutter_test.dart';
import 'package:family_to_study_ios/main.dart';

void main() {
  testWidgets('FamilyOSApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FamilyOSApp());
    expect(find.byType(FamilyOSApp), findsOneWidget);
  });
}
