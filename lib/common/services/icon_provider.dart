import 'dart:io';
import 'package:flutter/material.dart';

class IconProvider {
  static String? findIcon(String iconName) {
    if (iconName.isEmpty) return null;
    
    if (iconName.startsWith('/') && File(iconName).existsSync()) {
      return iconName;
    }
    
    final systemPaths = [
      '/usr/share/icons',
      '/usr/local/share/icons',
      '/usr/share/pixmaps',
      '/usr/local/share/pixmaps',
      '${Platform.environment['HOME']}/.icons',
      '${Platform.environment['HOME']}/.local/share/icons',
      '/var/lib/flatpak/exports/share/icons',
      '${Platform.environment['HOME']}/.local/share/flatpak/exports/share/icons',
      '/var/lib/snapd/desktop/icons',
    ].where((path) => Directory(path).existsSync()).toList();
    
    final themeSearchOrder = [
      _detectIconTheme(),
      'hicolor',
      'Adwaita',
      'gnome',
      'oxygen',
      'Humanity',
      'elementary',
      'breeze',
      'Papirus',
      'Numix',
      'default',
    ].where((theme) => theme != null).toSet().toList();
    
    final sizes = ['512x512', '256x256', '128x128', '96x96', '72x72', '64x64', '48x48', '32x32', '24x24', '22x22', '16x16', 'scalable'];
    final categories = ['apps', 'actions', 'devices', 'categories', 'places', 'status', 'emblems', 'mimetypes'];
    final extensions = ['.svg', '.png', '.xpm'];
    
    for (final basePath in systemPaths) {
      for (final theme in themeSearchOrder) {
        final themePath = '$basePath/$theme';
        if (!Directory(themePath).existsSync()) continue;

        for (final size in sizes) {
          for (final category in categories) {
            final sizeDir = '$themePath/$size/$category';
            if (!Directory(sizeDir).existsSync()) continue;

            for (final ext in extensions) {
              final path = '$sizeDir/$iconName$ext';
              if (File(path).existsSync()) {
                return path;
              }
            }

            final path = '$sizeDir/$iconName';
            if (File(path).existsSync()) {
              return path;
            }
          }
        }
      }
    }

    for (final ext in extensions) {
      final pixmapPath = '/usr/share/pixmaps/$iconName$ext';
      if (File(pixmapPath).existsSync()) {
        return pixmapPath;
      }
    }

    final pixmapPath = '/usr/share/pixmaps/$iconName';
    if (File(pixmapPath).existsSync()) {
      return pixmapPath;
    }

    return null;
  }

  static ImageProvider<Object>? getIcon(String iconName) {
    final path = findIcon(iconName);
    if (path != null) {
      return FileImage(File(path));
    }
    return null;
  }

  static String? _detectIconTheme() {
    try {
      final result = Process.runSync('gsettings', ['get', 'org.gnome.desktop.interface', 'icon-theme']);
      if (result.exitCode == 0) {
        final theme = result.stdout.toString().trim()
            .replaceAll("'", '')
            .replaceAll('"', '');
        if (theme.isNotEmpty && theme != 'default') {
          return theme;
        }
      }
    } catch (_) {}

    try {
      final home = Platform.environment['HOME'];
      if (home != null) {
        final configFile = File('$home/.config/gtk-3.0/settings.ini');
        if (configFile.existsSync()) {
          final content = configFile.readAsStringSync();
          final match = RegExp(r'gtk-icon-theme-name\s*=\s*([^\s]+)', caseSensitive: false)
              .firstMatch(content);
          if (match != null && match.group(1) != null) {
            final theme = match.group(1)!
                .replaceAll('"', '')
                .replaceAll("'", '');
            if (theme.isNotEmpty && theme != 'default') {
              return theme;
            }
          }
        }
      }
    } catch (_) {}

    return null;
  }
}