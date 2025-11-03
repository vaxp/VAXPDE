import 'dart:convert';
import 'package:desktop_multi_window/desktop_multi_window.dart';

/// Small helper to create and toggle a separate launcher window.
///
/// Behavior:
/// - On first toggle, creates a window hosting the `launcher` entrypoint.
/// - On subsequent toggles, closes the window if open.
///
/// Note: the actual launcher UI should be registered as an entrypoint named
/// 'launcher' in the same Flutter project if required by the plugin. We
/// attempt to create a simple window and send it a small payload.
class LauncherWindow {
  static WindowController? _controller;
  static bool _visible = false;

  /// Toggle the launcher window. Creates the window on first call and then
  /// shows/hides it on subsequent toggles.
  /// Returns true if the multi-window operation was performed, false on failure.
  static Future<bool> toggleLauncherWindow() async {
    try {
      if (_controller == null) {
        final payload = jsonEncode({'type': 'launcher'});
        final cfg = WindowConfiguration(arguments: payload, hiddenAtLaunch: false);
        // Create and show window
        _controller = await WindowController.create(cfg);
        _visible = true;
        await _controller!.show();
        // success
        // ignore: avoid_print
        print('[LauncherWindow] created window id=${_controller!.windowId}');
        return true;
      }

      // Toggle visibility
      if (_visible) {
        await _controller!.hide();
        _visible = false;
        // ignore: avoid_print
        print('[LauncherWindow] hid window id=${_controller!.windowId}');
      } else {
        await _controller!.show();
        _visible = true;
        // ignore: avoid_print
        print('[LauncherWindow] showed window id=${_controller!.windowId}');
      }
      return true;
    } catch (e, st) {
      // Diagnostic print for why multi-window failed
      // ignore: avoid_print
      print('[LauncherWindow] failed to toggle window: $e\n$st');
      return false;
    }
  }
}
