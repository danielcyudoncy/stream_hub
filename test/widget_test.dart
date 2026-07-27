import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/main.dart';

void main() {
  testWidgets('StreamHub Pro app renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const StreamHubApp());
    expect(find.byType(StreamHubApp), findsOneWidget);
  });
}
