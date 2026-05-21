import 'package:flutter_test/flutter_test.dart';
import 'package:kittentts_basic_example/main.dart';

void main() {
  testWidgets('shows KittenTTS controls', (tester) async {
    await tester.pumpWidget(const KittenTTSExampleApp());

    expect(find.text('KittenTTS Example'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Model'), findsWidgets);
  });
}
