import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/tuner_screen.dart';
import 'features/tuner_viewmodel.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TunerViewModel()),
      ],
      child: const FluteTunerApp(),
    ),
  );
}

class FluteTunerApp extends StatelessWidget {
  const FluteTunerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flute Tuner MVP',
      theme: ThemeData.dark(),
      home: const TunerScreen(),
    );
  }
}