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

  // Tries to resolve an icon name to an AssetImage or FileImage
  // Supports system icon themes and all icon types
  static ImageProvider<Object>? _iconProvider(String iconName) {
    if (iconName.isEmpty) return null;
    
    // Absolute path
    if (iconName.contains('/') && File(iconName).existsSync()) {
      return FileImage(File(iconName));
    }
    
    // Try to detect current icon theme
    final iconTheme = _detectIconTheme();
    final exts = ['.png', '.svg', '.xpm'];
    
    // Search in current theme first, then fallback to other common themes
    final themeSearchOrder = [
      iconTheme, // Current theme
      'hicolor',
      'Adwaita',
      'Adwaita-dark',
      'ubuntu-mono-dark',
      'ubuntu-mono-light',
      'Papirus',
      'Numix',
      'Faenza',
      'Moka',
      'breeze',
      'gnome',
      'elementary',
    ];
    
    // Icon sizes to check (larger first for better quality)
    final sizes = ['512', '256', '128', '96', '64', '48', '32', '24', '22', '16'];
    
    // Try to find icon in theme directories
    for (final theme in themeSearchOrder) {
      if (theme == null || theme.isEmpty) continue;
      
      // Check /usr/share/icons/[theme]/
      final themeDir = '/usr/share/icons/$theme/';
      if (!Directory(themeDir).existsSync()) continue;
      
      // Check all sizes and subdirectories
      for (final size in sizes) {
        final dirsToCheck = [
          '$themeDir/${size}x$size/apps',
          '$themeDir/${size}x$size/categories',
          '$themeDir/${size}x$size/emblems',
          '$themeDir/${size}x$size/mimetypes',
          '$themeDir/${size}x$size/places',
          '$themeDir/${size}x$size/status',
          '$themeDir/apps', // Some themes don't have size directories
          '$themeDir/categories',
          '$themeDir/emblems',
          '$themeDir/mimetypes',
          '$themeDir/places',
          '$themeDir/status',
        ];
        
        for (final dirPath in dirsToCheck) {
          if (!Directory(dirPath).existsSync()) continue;
          
          // Try different extensions
          for (final ext in exts) {
            final path = '$dirPath/$iconName$ext';
            if (File(path).existsSync()) {
              if (ext == '.svg') {
                // Skip SVG for now as it requires flutter_svg package
                // Could integrate flutter_svg here if needed
                continue;
              }
              return FileImage(File(path));
            }
          }
          
          // Try without extension
          final path = '$dirPath/$iconName';
          if (File(path).existsSync()) {
            return FileImage(File(path));
          }
        }
      }
    }
    
    // Fallback to generic pixmaps
    final pixmapsDir = '/usr/share/pixmaps/';
    for (final ext in exts) {
      final path = '$pixmapsDir/$iconName$ext';
      if (File(path).existsSync()) {
        if (ext != '.svg') {
          return FileImage(File(path));
        }
      }
    }
    
    // Try pixmaps without extension
    final pixmapPath = '$pixmapsDir/$iconName';
    if (File(pixmapPath).existsSync()) {
      return FileImage(File(pixmapPath));
    }
    
    return null;
  }
  
  // Detect current icon theme from system
  static String? _detectIconTheme() {
    try {
      // Try to read from gsettings (GNOME/Ubuntu)
      final gsettings = Process.runSync('gsettings', ['get', 'org.gnome.desktop.interface', 'icon-theme']);
      if (gsettings.exitCode == 0) {
        final theme = gsettings.stdout.toString().trim().replaceAll("'", '').replaceAll('"', '');
        if (theme.isNotEmpty && theme != 'default') {
          return theme;
        }
      }
    } catch (_) {}
    
    try {
      // Try to read from ~/.config/gtk-3.0/settings.ini
      final configFile = File('${Platform.environment['HOME']}/.config/gtk-3.0/settings.ini');
      if (configFile.existsSync()) {
        final content = configFile.readAsStringSync();
        final match = RegExp(r'gtk-icon-theme-name\s*=\s*([^\s]+)', caseSensitive: false).firstMatch(content);
        if (match != null && match.group(1) != null) {
          final theme = match.group(1)!.replaceAll('"', '').replaceAll("'", '');
          if (theme.isNotEmpty && theme != 'default') {
            return theme;
          }
        }
      }
    } catch (_) {}
    
    try {
      // Try to read from environment
      final iconTheme = Platform.environment['XDG_CURRENT_DESKTOP'];
      if (iconTheme != null && iconTheme.isNotEmpty) {
        // This doesn't give us the theme name, but we can use it as a hint
      }
    } catch (_) {}
    
    return null; // Will fall back to hicolor if null
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

// Helper widget for macOS dock icons
class _DockIcon extends StatefulWidget {
  final IconData? icon;
  final ImageProvider<Object>? iconData;
  final String? tooltip;
  final VoidCallback onTap;
  final String? name;

  const _DockIcon({
    this.icon,
    this.iconData,
    this.tooltip,
    required this.onTap,
    this.name,
  }) : assert(icon != null || iconData != null, 'Either icon or iconData must be provided');

  @override
  State<_DockIcon> createState() => _DockIconState();
}

class _DockIconState extends State<_DockIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.tooltip ?? widget.name ?? '',
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: widget.iconData != null ? null : Colors.transparent,
                      ),
                      child: widget.iconData != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image(
                                image: widget.iconData!,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Icon(
                              widget.icon ?? Icons.apps,
                              size: 48,
                              color: Colors.white.withOpacity(0.9),
                            ),
                    ),
                    // Running indicator dot
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Helper widget for quick toggle buttons
class _QuickToggleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _QuickToggleButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: active ? Colors.blue.withOpacity(0.15) : Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? Colors.blue.withOpacity(0.4) : Colors.black.withOpacity(0.08),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: active ? Colors.blue : Colors.black87,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.blue : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper widget for small circular toggle buttons
class _SmallToggleButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _SmallToggleButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: active ? Colors.blue.withOpacity(0.15) : Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? Colors.blue.withOpacity(0.4) : Colors.black.withOpacity(0.08),
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            color: active ? Colors.blue : Colors.black87,
            size: 28,
          ),
        ),
      ),
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
  
  // For volume and brightness control
  double _volume = 0.5;
  double _brightness = 0.75;
  
  // Track if app grid dialog is open
  bool _isAppGridOpen = false;

  @override
  void initState() {
    super.initState();
    _allAppsFuture = DesktopEntry.loadAll();
    // Load pinned apps
    _loadPinnedApps();

    _now = DateTime.now();
    _timeStream = ticker;
    _initializeVolumeAndBrightness();
  }

  // Load pinned apps from desktop entries
  Future<void> _loadPinnedApps() async {
    final apps = await _allAppsFuture;
    if (!mounted) return;
    setState(() {
      _pinned = apps.take(6).toList();
    });
  }

  // Initialize volume and brightness from system
  Future<void> _initializeVolumeAndBrightness() async {
    // Get current volume
    try {
      final result = await Process.run('pactl', ['get-sink-volume', '@DEFAULT_SINK@']);
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        // Extract percentage from output like "Volume: front-left: 36864 /  56% / -11.53 dB"
        final match = RegExp(r'(\d+)%').firstMatch(output);
        if (match != null) {
          final percentage = int.parse(match.group(1)!);
          if (mounted) {
            setState(() {
              _volume = percentage / 100.0;
            });
          }
        }
      }
    } catch (e) {
      // Fallback to amixer if pactl fails
      try {
        final result = await Process.run('amixer', ['sget', 'Master']);
        if (result.exitCode == 0) {
          final output = result.stdout.toString();
          final match = RegExp(r'\[(\d+)%\]').firstMatch(output);
          if (match != null) {
            final percentage = int.parse(match.group(1)!);
            if (mounted) {
              setState(() {
                _volume = percentage / 100.0;
              });
            }
          }
        }
      } catch (_) {}
    }

    // Get current brightness
    try {
      final result = await Process.run('brightnessctl', ['get']);
      if (result.exitCode == 0) {
        final maxResult = await Process.run('brightnessctl', ['max']);
        if (maxResult.exitCode == 0) {
          final current = int.parse(result.stdout.toString().trim());
          final max = int.parse(maxResult.stdout.toString().trim());
          if (mounted) {
            setState(() {
              _brightness = current / max;
            });
          }
        }
      }
    } catch (e) {
      // Try reading from /sys/class/backlight/ directly
      try {
        final backlightDirs = Directory('/sys/class/backlight/').listSync();
        if (backlightDirs.isNotEmpty) {
          final dir = backlightDirs.first.path;
          final brightnessFile = File('$dir/brightness');
          final maxBrightnessFile = File('$dir/max_brightness');
          if (await brightnessFile.exists() && await maxBrightnessFile.exists()) {
            final brightness = int.parse(await brightnessFile.readAsString());
            final maxBrightness = int.parse(await maxBrightnessFile.readAsString());
            if (mounted) {
              setState(() {
                _brightness = brightness / maxBrightness;
              });
            }
          }
        }
      } catch (_) {}
    }
  }

  // Set system volume
  Future<void> _setVolume(double volume) async {
    final volumePercent = (volume * 100).toInt();
    try {
      // Try pactl first
      final result = await Process.run('pactl', ['set-sink-volume', '@DEFAULT_SINK@', '$volumePercent%']);
      if (result.exitCode == 0) {
        if (mounted) {
          setState(() {
            _volume = volume;
          });
        }
        return;
      }
    } catch (e) {
      // Fallback to amixer
      try {
        final result = await Process.run('amixer', ['set', 'Master', '$volumePercent%']);
        if (result.exitCode == 0 && mounted) {
          setState(() {
            _volume = volume;
          });
        }
      } catch (_) {}
    }
  }

  // Set system brightness
  Future<void> _setBrightness(double brightness) async {
    try {
      // Try brightnessctl first
      final brightnessPercent = (brightness * 100).toInt();
      final result = await Process.run('brightnessctl', ['set', '$brightnessPercent%']);
      if (result.exitCode == 0 && mounted) {
        setState(() {
          _brightness = brightness;
        });
        return;
      }
    } catch (e) {
      // Fallback to direct file write
      try {
        final backlightDirs = Directory('/sys/class/backlight/').listSync();
        if (backlightDirs.isNotEmpty) {
          final dir = backlightDirs.first.path;
          final maxBrightnessFile = File('$dir/max_brightness');
          if (await maxBrightnessFile.exists()) {
            final maxBrightness = int.parse(await maxBrightnessFile.readAsString());
            final targetBrightness = (brightness * maxBrightness).round();
            final brightnessFile = File('$dir/brightness');
            await brightnessFile.writeAsString(targetBrightness.toString());
            if (mounted) {
              setState(() {
                _brightness = brightness;
              });
            }
          }
        }
      } catch (_) {}
    }
  }

  void _openAppGrid(List<DesktopEntry> apps) async {
    setState(() {
      _isAppGridOpen = true;
    });
    
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
    
    setState(() {
      _isAppGridOpen = false;
    });
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

    // Store the screen height for positioning
    double screenHeight = MediaQuery.of(context).size.height;

    showGeneralDialog(
      context: context,
      barrierColor: Colors.black12, // Subtle backdrop
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
              begin: const Offset(0, -1), // Start from top
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.topRight,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0, right: 16.0),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 380,
                  constraints: BoxConstraints(
                    maxHeight: screenHeight * 0.85,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 40,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.black.withOpacity(0.08),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Control Center',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () => Navigator.of(context).pop(),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                // Connectivity section
                                Row(
                                  children: [
                                    Expanded(
                                      child: _QuickToggleButton(
                                        icon: Icons.wifi,
                                        label: 'Wi-Fi',
                                        active: wifiEnabled,
                                        onTap: wifiEnabled ? _disableInternet : _enableInternet,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _SmallToggleButton(
                                      icon: Icons.bluetooth,
                                      active: bluetoothEnabled,
                                      onTap: _toggleBluetooth,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Focus and additional controls
                                Row(
                                  children: [
                                    Expanded(
                                      child: _QuickToggleButton(
                                        icon: Icons.airplanemode_active,
                                        label: 'Airplane',
                                        active: airplaneMode,
                                        onTap: _toggleAirplaneMode,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _SmallToggleButton(
                                      icon: Icons.dark_mode,
                                      active: false,
                                      onTap: () {},
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Display brightness
                                Container(
                                  height: 60,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.black.withOpacity(0.06),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _brightness < 0.33 ? Icons.brightness_3 :
                                        _brightness < 0.66 ? Icons.brightness_6 : Icons.brightness_7,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          'Display',
                                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Slider(
                                          value: _brightness,
                                          onChanged: _setBrightness,
                                          activeColor: Colors.white,
                                          inactiveColor: Colors.grey.withOpacity(0.3),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Sound volume
                                Container(
                                  height: 60,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.black.withOpacity(0.06),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _volume == 0 ? Icons.volume_off :
                                        _volume < 0.5 ? Icons.volume_down : Icons.volume_up,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          'Sound',
                                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Slider(
                                          value: _volume,
                                          onChanged: _setVolume,
                                          activeColor: Colors.white,
                                          inactiveColor: Colors.grey.withOpacity(0.3),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Settings button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.settings),
                                    label: const Text('Settings'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white.withOpacity(0.7),
                                      foregroundColor: Colors.black87,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        side: BorderSide(
                                          color: Colors.black.withOpacity(0.1),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      _openSettings();
                                    },
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Background image picker
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.image),
                                    label: const Text('Change Background'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white.withOpacity(0.7),
                                      foregroundColor: Colors.black87,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        side: BorderSide(
                                          color: Colors.black.withOpacity(0.1),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      pickAndSetBackground();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
                // Bottom bar: macOS dock style - only show when app grid is closed
                if (!_isAppGridOpen)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      // Left side apps
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // App Grid button
                            _DockIcon(
                              icon: Icons.apps,
                              tooltip: 'Show all apps',
                              onTap: () async {
                                final apps = await _allAppsFuture;
                                _openAppGrid(apps);
                              },
                            ),
                            // Separator
                            Container(
                              width: 1,
                              height: 32,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(0.5),
                              ),
                            ),
                            // Pinned apps
                            if (_pinned.isNotEmpty)
                              ..._pinned.asMap().entries.expand(
                                (entry) {
                                  if (entry.value.iconData != null) {
                                    return [
                                      _DockIcon(
                                        iconData: entry.value.iconData,
                                        tooltip: entry.value.name,
                                        onTap: () => _launchEntry(entry.value),
                                        name: entry.value.name,
                                      ),
                                      if (entry.key < _pinned.length - 1) const SizedBox(width: 4),
                                    ];
                                  } else {
                                    return [
                                      _DockIcon(
                                        icon: Icons.apps,
                                        tooltip: entry.value.name,
                                        onTap: () => _launchEntry(entry.value),
                                        name: entry.value.name,
                                      ),
                                      if (entry.key < _pinned.length - 1) const SizedBox(width: 4),
                                    ];
                                  }
                                },
                              ),
                            // Right side utilities separator
                            Container(
                              width: 1,
                              height: 32,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(0.5),
                              ),
                            ),
                            // Downloads folder
                            _DockIcon(
                              icon: Icons.folder,
                              tooltip: 'Downloads',
                              onTap: () async {
                                try {
                                  await Process.start('/bin/sh', ['-c', 'xdg-open ~/Downloads']);
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Failed to open Downloads')),
                                  );
                                }
                              },
                            ),
                            // Trash
                            _DockIcon(
                              icon: Icons.delete_outline,
                              tooltip: 'Trash',
                              onTap: () async {
                                try {
                                  await Process.start('/bin/sh', ['-c', 'xdg-open trash://']);
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Failed to open Trash')),
                                  );
                                }
                              },
                            ),
                          ],
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