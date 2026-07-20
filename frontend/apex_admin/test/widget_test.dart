import 'package:flutter_test/flutter_test.dart';
import 'package:apex_admin/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ApexAdminApp());
    // Verify the app renders without errors (splash screen loads)
    expect(find.byType(ApexAdminApp), findsOneWidget);
  });
}
