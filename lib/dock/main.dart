import 'package:flutter/material.dart';
import 'widgets/dock_bar.dart';

void main() {
  runApp(const DockApp());
}

class DockApp extends StatelessWidget {
  const DockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dock',
      theme: ThemeData(
        canvasColor: Colors.transparent,
        scaffoldBackgroundColor: Colors.transparent,
        useMaterial3: true,
      ),
      home: const DockHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DockHome extends StatelessWidget {
  const DockHome({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: Align(
        alignment: Alignment.bottomCenter,
        child: DockBar(),
      ),
    );
  }
}