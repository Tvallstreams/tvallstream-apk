import 'package:flutter/material.dart';
import 'home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TvAllStreamApp());
}

class TvAllStreamApp extends StatelessWidget {
  const TvAllStreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TVAllstream',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0E101A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF5A48F5),
          secondary: Color(0xFF5A48F5),
        ),
      ),
      home: const HomePage(),
    );
  }
}
