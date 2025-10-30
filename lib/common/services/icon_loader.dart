import 'dart:ffi';
import 'dart:io' show Platform, Directory, File;
import 'package:path/path.dart' as path;
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';

class IconLoader {
  static late final DynamicLibrary _lib;
  static late final void Function() _initGtk;
  static late final Pointer<Utf8> Function(Pointer<Utf8>, int) _getIconPath;
  static late final void Function(Pointer<Utf8>) _freeIconPath;
  static bool _initialized = false;
  static bool _gtkAvailable = true;

  static void initialize() {
    if (_initialized) return;

    try {
      final libraryPath = _findLibrary();
      if (libraryPath != null) {
        _lib = DynamicLibrary.open(libraryPath);
        _initGtk = _lib.lookupFunction<Void Function(), void Function()>('init_gtk');
        _getIconPath = _lib.lookupFunction<
            Pointer<Utf8> Function(Pointer<Utf8>, Int32),
            Pointer<Utf8> Function(Pointer<Utf8>, int)>('get_icon_path');
        _freeIconPath = _lib.lookupFunction<
            Void Function(Pointer<Utf8>),
            void Function(Pointer<Utf8>)>('free_icon_path');
        _initGtk();
        _initialized = true;
      } else {
        _gtkAvailable = false;
      }
    } catch (e) {
      print('Failed to initialize GTK icon loader: $e');
      _gtkAvailable = false;
    }
  }

  static ImageProvider<Object>? getIcon(String iconName, {int size = 48}) {
    if (_gtkAvailable) {
      if (!_initialized) initialize();
      
      if (_initialized) {
        try {
          final iconPath = getIconPath(iconName, size: size);
          if (iconPath != null) {
            return _createImageProvider(iconPath);
          }
        } catch (e) {
          print('GTK icon lookup failed: $e');
        }
      }
    }
    return null;
  }

  static String? getIconPath(String iconName, {int size = 48}) {
    if (!_initialized) initialize();
    if (!_gtkAvailable) return null;

    final iconNamePtr = iconName.toNativeUtf8();
    final resultPtr = _getIconPath(iconNamePtr, size);
    malloc.free(iconNamePtr);

    if (resultPtr.address == 0) return null;
    final result = resultPtr.toDartString();
    _freeIconPath(resultPtr);
    return result;
  }

  static String? _findLibrary() {
    if (!Platform.isLinux) return null;

    final libName = 'libicon_loader.so';
    final locations = [
      path.join(Directory.current.path, 'build', 'lib', libName),
      path.join(Directory.current.path, 'lib', libName),
      '/usr/local/lib/$libName',
      '/usr/lib/$libName',
    ];

    for (final location in locations) {
      if (File(location).existsSync()) {
        return location;
      }
    }
    return null;
  }

  static bool _isSvgFile(String path) {
    if (path.toLowerCase().endsWith('.svg')) {
      try {
        final file = File(path);
        if (!file.existsSync()) return false;
        
        final bytes = file.readAsBytesSync().take(100).toList();
        final content = String.fromCharCodes(bytes);
        return content.contains('<?xml') || content.contains('<svg');
      } catch (e) {
        print('Error checking SVG file: $e');
        return false;
      }
    }
    return false;
  }

  static ImageProvider<Object>? _createImageProvider(String path) {
    if (!File(path).existsSync()) {
      print('File does not exist: $path');
      return null;
    }

    try {
      if (_isSvgFile(path)) {
        print('Skipping SVG file: $path');
        return null;
      }
      return FileImage(File(path));
    } catch (e) {
      print('Error creating image provider for $path: $e');
      return null;
    }
  }
}