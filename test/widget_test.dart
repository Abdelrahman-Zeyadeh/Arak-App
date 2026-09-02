import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arak_app/main.dart';

void main() {
  testWidgets('Arak app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ArakApp(),
      ),
    );
    expect(find.byType(ArakApp), findsOneWidget);
  });
}


