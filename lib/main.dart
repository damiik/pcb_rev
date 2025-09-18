import 'package:flutter/material.dart';
import 'project/presentation/main_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PCB Reverse Engineering',
      theme: ThemeData.dark(),
      home: const PCBAnalyzerApp(),
    );
  }
}