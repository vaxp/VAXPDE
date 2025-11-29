/// Multi-window launcher support removed.
///
/// This helper used to create a separate window using `desktop_multi_window`.
/// The project was reverted to open the launcher inside the main window, so
/// this function now intentionally does not create a separate window and
/// returns `false` to indicate the caller should handle opening the launcher
/// UI in the same engine/process.
class LauncherWindow {
  /// Previously created a new window; now always return false to signal the
  /// caller to open the launcher in the current window.
  static Future<bool> toggleLauncherWindow() async {
    return false;
  }
}
