// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/main.dart';
import 'package:tunner/presentation/tuner_viewmodel.dart';

void main() {
  testWidgets('App smoke test initializes FluteTunerApp', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => TunerViewModel()),
        ],
        child: const FluteTunerApp(),
      ),
    );
    expect(find.byType(FluteTunerApp), findsOneWidget);
  });
}
