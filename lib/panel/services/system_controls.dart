import 'dart:io';

class SystemControls {
  static Future<bool> getWifiStatus() async {
    try {
      final result = await Process.run('nmcli', ['radio', 'wifi']);
      return result.exitCode == 0 && result.stdout.toString().trim() == 'enabled';
    } catch (_) {
      return false;
    }
  }

  static Future<bool> getBluetoothStatus() async {
    try {
      final result = await Process.run('rfkill', ['list', 'bluetooth']);
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        return !output.contains('Soft blocked: yes');
      }
    } catch (_) {}
    return false;
  }

  static Future<bool> getAirplaneModeStatus() async {
    try {
      final result = await Process.run('nmcli', ['radio', 'all']);
      if (result.exitCode == 0) {
        final out = result.stdout.toString();
        return out.contains('disabled');
      }
    } catch (_) {}
    return false;
  }

  static Future<void> toggleWifi(bool enable) async {
    try {
      await Process.run('nmcli', ['radio', 'wifi', enable ? 'on' : 'off']);
    } catch (_) {}
  }

  static Future<void> toggleBluetooth(bool enable) async {
    try {
      await Process.run('rfkill', [enable ? 'unblock' : 'block', 'bluetooth']);
    } catch (_) {}
  }

  static Future<void> toggleAirplaneMode(bool enable) async {
    try {
      await Process.run('nmcli', ['radio', 'all', enable ? 'off' : 'on']);
    } catch (_) {}
  }

  static Future<double> getVolume() async {
    try {
      final result = await Process.run('pactl', ['get-sink-volume', '@DEFAULT_SINK@']);
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final match = RegExp(r'(\d+)%').firstMatch(output);
        if (match != null) {
          final percentage = int.parse(match.group(1)!);
          return percentage / 100.0;
        }
      }
    } catch (_) {
      try {
        final result = await Process.run('amixer', ['sget', 'Master']);
        if (result.exitCode == 0) {
          final output = result.stdout.toString();
          final match = RegExp(r'\[(\d+)%\]').firstMatch(output);
          if (match != null) {
            final percentage = int.parse(match.group(1)!);
            return percentage / 100.0;
          }
        }
      } catch (_) {}
    }
    return 0.5;
  }

  static Future<void> setVolume(double volume) async {
    final volumePercent = (volume * 100).toInt();
    try {
      await Process.run('pactl', ['set-sink-volume', '@DEFAULT_SINK@', '$volumePercent%']);
    } catch (_) {
      try {
        await Process.run('amixer', ['set', 'Master', '$volumePercent%']);
      } catch (_) {}
    }
  }

  static Future<double> getBrightness() async {
    try {
      final result = await Process.run('brightnessctl', ['get']);
      if (result.exitCode == 0) {
        final maxResult = await Process.run('brightnessctl', ['max']);
        if (maxResult.exitCode == 0) {
          final current = int.parse(result.stdout.toString().trim());
          final max = int.parse(maxResult.stdout.toString().trim());
          return current / max;
        }
      }
    } catch (_) {
      try {
        final backlightDirs = Directory('/sys/class/backlight/').listSync();
        if (backlightDirs.isNotEmpty) {
          final dir = backlightDirs.first.path;
          final brightnessFile = File('$dir/brightness');
          final maxBrightnessFile = File('$dir/max_brightness');
          if (await brightnessFile.exists() && await maxBrightnessFile.exists()) {
            final brightness = int.parse(await brightnessFile.readAsString());
            final maxBrightness = int.parse(await maxBrightnessFile.readAsString());
            return brightness / maxBrightness;
          }
        }
      } catch (_) {}
    }
    return 0.75;
  }

  static Future<void> setBrightness(double brightness) async {
    try {
      final brightnessPercent = (brightness * 100).toInt();
      await Process.run('brightnessctl', ['set', '$brightnessPercent%']);
    } catch (_) {
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
          }
        }
      } catch (_) {}
    }
  }

  static Future<void> openSettings() async {
    try {
      await Process.start('/bin/sh', ['-c', 'gnome-control-center']);
    } catch (_) {}
  }
}