import 'dart:io';
import 'package:flutter/material.dart';
import 'widgets/clock_display.dart';
import 'widgets/quick_settings.dart';

void main() {
  runApp(const PanelApp());
}

class PanelApp extends StatelessWidget {
  const PanelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Panel',
      theme: ThemeData(
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        canvasColor: Colors.transparent,
        scaffoldBackgroundColor: Colors.transparent,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(125, 0, 170, 255),
        ),
      ),
      home: const PanelHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class PanelHome extends StatefulWidget {
  const PanelHome({super.key});

  @override
  State<PanelHome> createState() => _PanelHomeState();
}

class _PanelHomeState extends State<PanelHome> {
  String? _backgroundImagePath;
  DateTime _now = DateTime.now();
  late final Stream<DateTime> _timeStream;

  @override
  void initState() {
    super.initState();
    _timeStream = Stream<DateTime>.periodic(
      const Duration(seconds: 1),
      (_) => DateTime.now(),
    );
  }

  void _updateBackground(String? path) {
    setState(() {
      _backgroundImagePath = path;
    });
  }

  void _showQuickSettings() {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black12,
      barrierDismissible: true,
      barrierLabel: 'Control Center',
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -1),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return QuickSettings(
          onBackgroundChange: _updateBackground,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_backgroundImagePath != null)
            Image.file(
              File(_backgroundImagePath!),
              fit: BoxFit.cover,
            ),
          SafeArea(
            child: Column(
              children: [
                Container(
                  height: 56,
                  color: const Color.fromARGB(25, 255, 255, 255),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu),
                        tooltip: 'Quick Settings',
                        onPressed: _showQuickSettings,
                      ),
                      Expanded(
                        child: StreamBuilder<DateTime>(
                          stream: _timeStream,
                          initialData: _now,
                          builder: (context, snapshot) {
                            return ClockDisplay(time: snapshot.data ?? DateTime.now());
                          },
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}