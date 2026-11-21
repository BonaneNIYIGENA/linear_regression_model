import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_spending_app/main.dart';

// a tall screen, so every field of the scrolling page is built
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('the page has one text field per model input and a Predict button', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(const SchoolSpendingApp());

    expect(find.byType(TextField), findsNWidgets(9));
    expect(find.text('Predict'), findsOneWidget);
  });

  testWidgets('a missing value shows an error in the result area', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(const SchoolSpendingApp());

    await tester.tap(find.text('Predict'));
    await tester.pumpAndSettle(const Duration(seconds: 1));   // lets the scroll to the answer finish

    expect(find.textContaining('Please fill in every field'), findsOneWidget);
  });

  testWidgets('a field with fixed answers shows them as options to choose from', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(const SchoolSpendingApp());

    await tester.tap(find.widgetWithText(TextField, 'Sex'));
    await tester.pumpAndSettle();
    expect(find.text('Male'), findsWidgets);
    expect(find.text('Female'), findsWidgets);

    await tester.tap(find.text('Female').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Female'), findsOneWidget);
  });

  testWidgets('a number field accepts a wrong value so the API can refuse it', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(const SchoolSpendingApp());

    await tester.enterText(find.widgetWithText(TextField, 'Age (years)'), '5.5');
    expect(find.text('5.5'), findsOneWidget);
  });
}
