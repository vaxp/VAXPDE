import 'dart:io';
import 'package:flutter/material.dart';
import '../../common/models/desktop_entry.dart';

class AppLauncher {
  static Future<void> launchEntry(DesktopEntry entry, {BuildContext? context}) async {
    final cmd = entry.exec;
    if (cmd == null) return;
    
    // Remove placeholders like %U, %f, etc.
    final cleaned = cmd.replaceAll(RegExp(r'%[a-zA-Z]'), '').trim();
    if (cleaned.isEmpty) return;
    
    try {
      await Process.start('/bin/sh', ['-c', cleaned]);
    } catch (e) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to launch ${entry.name}: $e')),
        );
      }
    }
  }

  static Future<void> openDirectory(String path, {BuildContext? context}) async {
    try {
      await Process.start('/bin/sh', ['-c', 'xdg-open $path']);
    } catch (e) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open directory: $e')),
        );
      }
    }
  }
}