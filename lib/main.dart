import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VoiceInputApp());
}

class VoiceInputApp extends StatelessWidget {
  const VoiceInputApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '离线语音输入法',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}