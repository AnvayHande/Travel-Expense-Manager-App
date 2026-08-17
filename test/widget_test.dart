import 'package:flutter_test/flutter_test.dart';
import 'package:trip_expense_manager/app.dart';

void main() {
  testWidgets('App should build without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const TripExpenseApp());
    expect(find.text('Trip Expense Manager'), findsOneWidget);
  });
}
