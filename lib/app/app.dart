import 'package:chino/app/theme/chino_theme.dart';
import 'package:chino/features/home/home_screen.dart';
import 'package:flutter/material.dart';

class ChinoApp extends StatelessWidget {
  const ChinoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Chino',
        theme: ChinoTheme.light(),
        darkTheme: ChinoTheme.dark(),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      );
}
