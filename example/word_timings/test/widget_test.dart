import 'package:flutter_test/flutter_test.dart';
import 'package:kittentts_word_timings_example/main.dart';

void main() {
  testWidgets('shows word timing controls', (tester) async {
    await tester.pumpWidget(const WordTimingsExampleApp());

    expect(find.text('Word Timings'), findsOneWidget);
    expect(find.text('TEXT'), findsOneWidget);
    expect(find.text('VOICE'), findsOneWidget);
  });
}
