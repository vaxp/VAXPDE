import 'package:flutter/material.dart';

class ClockDisplay extends StatelessWidget {
  final DateTime time;

  const ClockDisplay({
    super.key,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}";
    
    return Center(
      child: Text(
        timeStr,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}