import 'package:flutter_test/flutter_test.dart';

import 'package:todo_app/main.dart';

void main() {
  testWidgets('Todo app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TodoApp());

    // Verify that the login screen appears
    expect(find.text('Todo App'), findsOneWidget);
    expect(find.text('Connexion'), findsOneWidget);
  });
}
