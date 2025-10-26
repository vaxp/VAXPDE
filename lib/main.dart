
import 'package:vaxp_panel/_mac_shortcut_tile.dart';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';

void main() {
  runApp(const PanelApp());
}

class PanelApp extends StatelessWidget {
  const PanelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Linux Panel',
      theme: ThemeData(
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        canvasColor: Colors.transparent ,
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

/// Minimal DesktopEntry model included inline so the file compiles without
/// separate files; replace with full implementation later if needed.
class DesktopEntry {
  final String name;
  final String? exec;
  final ImageProvider<Object>? iconData;

  DesktopEntry({required this.name, this.exec, this.iconData});

  static Future<List<DesktopEntry>> loadAll() async {
    // Standard locations for .desktop files
    final List<String> dirs = [
      '/usr/share/applications',
      '/usr/local/share/applications',
      if (Platform.environment['XDG_DATA_HOME'] != null)
        '${Platform.environment['XDG_DATA_HOME']!}/applications'
      else
        Platform.environment['HOME'] != null
            ? '${Platform.environment['HOME']!}/.local/share/applications'
            : '',
    ];

    final Set<String> seen = {};
    final List<DesktopEntry> entries = [];

    for (final dir in dirs) {
      final d = Directory(dir);
      if (!await d.exists()) continue;
      await for (final file in d.list()) {
        if (!file.path.endsWith('.desktop')) continue;
        try {
          final lines = await File(file.path).readAsLines();
          String? name;
          String? exec;
          String? icon;
          bool inDesktopEntry = false;
          for (final line in lines) {
            final l = line.trim();
            if (l == '[Desktop Entry]') inDesktopEntry = true;
            if (!inDesktopEntry || l.startsWith('#')) continue;
            if (l.startsWith('Name=')) name = l.substring(5);
            if (l.startsWith('Exec=')) exec = l.substring(5);
            if (l.startsWith('Icon=')) icon = l.substring(5);
            if (name != null && exec != null) break;
          }
          if (name != null && exec != null && !seen.contains(name)) {
            seen.add(name);
            entries.add(
              DesktopEntry(
                name: name,
                exec: exec,
                iconData: icon != null ? _iconProvider(icon) : null,
              ),
            );
          }
        } catch (_) {
          // Ignore parse errors
        }
      }
    }
    entries.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return entries;
  }

  // Tries to resolve an icon name to an AssetImage or FileImage. For now, only supports absolute paths or PNG/SVG in /usr/share/icons/hicolor/48x48/apps/.
  static ImageProvider<Object>? _iconProvider(String iconName) {
    if (iconName.isEmpty) return null;
    // Absolute path
    if (iconName.contains('/') && File(iconName).existsSync()) {
      return FileImage(File(iconName));
    }
    // Try common icon theme locations and extensions
    final iconDirs = [
      '/usr/share/icons/hicolor/48x48/apps/',
      '/usr/share/icons/hicolor/64x64/apps/',
      '/usr/share/icons/hicolor/128x128/apps/',
      '/usr/share/pixmaps/',
      '/usr/share/icons/Adwaita/48x48/apps/',
      '/usr/share/icons/Adwaita/64x64/apps/',
      '/usr/share/icons/Adwaita/128x128/apps/',
    ];
    final exts = ['.png', '.xpm', '.svg'];
    for (final dir in iconDirs) {
      for (final ext in exts) {
        final path = dir + iconName + ext;
        if (File(path).existsSync()) {
          if (ext == '.svg') {
            // Flutter does not support SVG natively; skip or use flutter_svg if available
            continue;
          }
          return FileImage(File(path));
        }
      }
    }
    // Try with no extension (some pixmaps are just the name)
    for (final dir in iconDirs) {
      final path = dir + iconName;
      if (File(path).existsSync()) {
        return FileImage(File(path));
      }
    }
    // Fallback: use a default Material icon (via AssetImage or null)
    return null;
  }
}

/// Minimal AppGrid widget so the app compiles; it shows a grid of apps and calls
/// onLaunch when an item is tapped.
class AppGrid extends StatelessWidget {
  final List<DesktopEntry> apps;
  final void Function(DesktopEntry) onLaunch;

  const AppGrid({super.key, required this.apps, required this.onLaunch});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
       
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(

        crossAxisCount: 6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: apps.length,
      itemBuilder: (context, index) {


        final e = apps[index];
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.of(context).maybePop();
            onLaunch(e);
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.transparent),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.transparent,
                  radius: 28,
                  backgroundImage: e.iconData,
                  child: e.iconData == null ? Icon(Icons.apps, size: 28) : null,
                ),
                const SizedBox(height: 8),
                Text(e.name, overflow: TextOverflow.ellipsis, maxLines: 1),
              ],
            ),
          ),
        );
      },
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
  late Future<List<DesktopEntry>> _allAppsFuture;
  List<DesktopEntry> _pinned = [];
  // For time display
  late DateTime _now;
  late final ticker = Stream<DateTime>.periodic(const Duration(seconds: 1), (_) => DateTime.now());
  late final Stream<DateTime> _timeStream;

  @override
  void initState() {
    super.initState();
    _allAppsFuture = DesktopEntry.loadAll();
    // default pinned: first few apps when available
    _allAppsFuture.then((list) {
      if (!mounted) return;
      setState(() {
        if (_pinned.isEmpty) _pinned = list.take(6).toList();
      });
    });

    _now = DateTime.now();
    _timeStream = ticker;
  }

  void _openAppGrid(List<DesktopEntry> apps) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black38,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: SizedBox(
          width: 1200,
          height: 900,
          child: AppGrid(apps: apps, onLaunch: _launchEntry),
        ),
      ),
    );
  }

  void _launchEntry(DesktopEntry entry) async {
    final cmd = entry.exec;
    if (cmd == null) return;
    // remove placeholders like %U, %f, etc.
    final cleaned = cmd.replaceAll(RegExp(r'%[a-zA-Z]'), '').trim();
    if (cleaned.isEmpty) return;
    try {
      await Process.start('/bin/sh', ['-c', cleaned]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to launch ${entry.name}: $e')),
      );
    }
  }

  void _showQuickSettings() async {
    // Query current states for WiFi, airplane mode, Bluetooth
    bool wifiEnabled = false;
    bool airplaneMode = false;
    bool bluetoothEnabled = false;
    try {
      final wifi = await Process.run('nmcli', ['radio', 'wifi']);
      wifiEnabled = wifi.exitCode == 0 && wifi.stdout.toString().trim() == 'enabled';
    } catch (_) {}
    try {
      final radio = await Process.run('nmcli', ['radio', 'all']);
      if (radio.exitCode == 0) {
        final out = radio.stdout.toString();
        airplaneMode = out.contains('disabled');
      }
    } catch (_) {}
    try {
      final bt = await Process.run('rfkill', ['list', 'bluetooth']);
      if (bt.exitCode == 0) {
        final out = bt.stdout.toString();
        bluetoothEnabled = !out.contains('Soft blocked: yes');
      }
    } catch (_) {}

    Future<void> pickAndSetBackground() async {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) {
        setState(() {
          _backgroundImagePath = result.files.single.path;
        });
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Background image set!')));
      }
    }

    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Center(
          child: Container(

            width: 420,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
            decoration: BoxDecoration(
              color: const Color.fromARGB(25, 255, 255, 255), // 10% opacity (90% transparent)
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Container(
                  color: const Color.fromARGB(25, 255, 255, 255),
               child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quick Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Shortcuts section
                  Material(
                    color: Colors.transparent,
                    child: Column(
                      children: [
                        MacShortcutTile(
                          icon: Icons.wifi,
                          label: wifiEnabled ? 'Disable Internet' : 'Enable Internet',
                          onTap: wifiEnabled ? _disableInternet : _enableInternet,
                          active: wifiEnabled,
                        ),
                        const SizedBox(height: 8),
                        MacShortcutTile(
                          icon: Icons.airplanemode_active,
                          label: 'Airplane Mode',
                          onTap: _toggleAirplaneMode,
                          active: airplaneMode,
                        ),
                        const SizedBox(height: 8),
                        MacShortcutTile(
                          icon: Icons.bluetooth,
                          label: 'Bluetooth',
                          onTap: _toggleBluetooth,
                          active: bluetoothEnabled,
                        ),
                        const SizedBox(height: 8),
                        MacShortcutTile(
                          icon: Icons.settings,
                          label: 'Settings',
                          onTap: _openSettings,
                          active: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Background image picker
                  ElevatedButton.icon(
                    icon: const Icon(Icons.image),
                    label: const Text('Set Background Image'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: pickAndSetBackground,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _disableInternet() async {
    Navigator.of(context).pop();
    // Uses nmcli to disable all WiFi and networking
    try {
      final result = await Process.run('nmcli', ['radio', 'wifi', 'off']);
      if (result.exitCode == 0) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WiFi disabled')));
      } else {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to disable WiFi: ${result.stderr}')));
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _enableInternet() async {
    Navigator.of(context).pop();
    // Uses nmcli to enable WiFi
    try {
      final result = await Process.run('nmcli', ['radio', 'wifi', 'on']);
      if (result.exitCode == 0) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WiFi enabled')));
      } else {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to enable WiFi: ${result.stderr}')));
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _toggleAirplaneMode() async {
    Navigator.of(context).pop();
    // Uses nmcli to toggle airplane mode
    try {
      // Get current state
      final status = await Process.run('nmcli', ['radio', 'all']);
      if (status.exitCode != 0) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to get radio status: ${status.stderr}')));
        return;
      }
      final output = status.stdout.toString();
      final isAirplane = output.contains('disabled');
      final cmd = isAirplane ? ['nmcli', 'radio', 'all', 'on'] : ['nmcli', 'radio', 'all', 'off'];
      final result = await Process.run(cmd[0], cmd.sublist(1));
      if (result.exitCode == 0) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAirplane ? 'Airplane mode off' : 'Airplane mode on')));
      } else {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to toggle airplane mode: ${result.stderr}')));
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _toggleBluetooth() async {
    Navigator.of(context).pop();
    // Uses rfkill to toggle Bluetooth
    try {
      // Get current state
      final status = await Process.run('rfkill', ['list', 'bluetooth']);
      if (status.exitCode != 0) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to get Bluetooth status: ${status.stderr}')));
        return;
      }
      final output = status.stdout.toString();
      final isBlocked = output.contains('Soft blocked: yes');
      final cmd = isBlocked ? ['rfkill', 'unblock', 'bluetooth'] : ['rfkill', 'block', 'bluetooth'];
      final result = await Process.run(cmd[0], cmd.sublist(1));
      if (result.exitCode == 0) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isBlocked ? 'Bluetooth enabled' : 'Bluetooth disabled')));
      } else {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to toggle Bluetooth: ${result.stderr}')));
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _openSettings() async {
    Navigator.of(context).pop();
    try {
      await Process.start('/bin/sh', ['-c', 'gnome-control-center']);
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to open Settings')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image if set
          if (_backgroundImagePath != null)
            Image.file(
              File(_backgroundImagePath!),
              fit: BoxFit.cover,
            ),
          // Main content
          SafeArea(
            child: Column(
              children: [
                // Top bar: drawer + time
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
                            final now = snapshot.data ?? DateTime.now();
                            final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
                            return Center(
                              child: Text(
                                timeStr,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 48), // right side empty for symmetry
                    ],
                  ),
                ),
                Expanded(child: Container()),
                // Bottom bar: app bar
                Container(
                  height: 40,
                  // color: Theme.of(context).colorScheme.surface,
                  color: const Color.fromARGB(110, 0, 0, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Show all apps',
                        icon: const Icon(Icons.apps),
                        onPressed: () async {
                          final apps = await _allAppsFuture;
                          _openAppGrid(apps);
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: _pinned
                                .map(
                                  (entry) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6.0,
                                    ),
                                    child: Tooltip(
                                      message: entry.name,
                                      child: InkWell(
                                        onTap: () => _launchEntry(entry),
                                        child: SizedBox(
                                          width: 44,
                                          height: 44,
                                          child: entry.iconData != null
                                              ? CircleAvatar(
                                                  backgroundImage: entry.iconData,
                                                )
                                              : CircleAvatar(
                                                  child: Icon(
                                                    Icons.apps,
                                                    size: 22,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
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