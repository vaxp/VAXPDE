import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../common/widgets/toggle_buttons.dart';
import '../services/system_controls.dart';

class QuickSettings extends StatefulWidget {
  final Function(String?) onBackgroundChange;

  const QuickSettings({
    super.key,
    required this.onBackgroundChange,
  });

  @override
  State<QuickSettings> createState() => _QuickSettingsState();
}

class _QuickSettingsState extends State<QuickSettings> {
  bool _wifiEnabled = false;
  bool _bluetoothEnabled = false;
  bool _airplaneMode = false;
  double _volume = 0.5;
  double _brightness = 0.75;

  @override
  void initState() {
    super.initState();
    _loadInitialStates();
  }

  Future<void> _loadInitialStates() async {
    final wifi = await SystemControls.getWifiStatus();
    final bluetooth = await SystemControls.getBluetoothStatus();
    final airplane = await SystemControls.getAirplaneModeStatus();
    final volume = await SystemControls.getVolume();
    final brightness = await SystemControls.getBrightness();

    if (mounted) {
      setState(() {
        _wifiEnabled = wifi;
        _bluetoothEnabled = bluetooth;
        _airplaneMode = airplane;
        _volume = volume;
        _brightness = brightness;
      });
    }
  }

  Future<void> _pickAndSetBackground() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      widget.onBackgroundChange(result.files.single.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Background image set!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

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
                    _buildHeader(),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildConnectivitySection(),
                            const SizedBox(height: 8),
                            _buildModeSection(),
                            const SizedBox(height: 16),
                            _buildBrightnessControl(),
                            const SizedBox(height: 8),
                            _buildVolumeControl(),
                            const SizedBox(height: 16),
                            _buildSettingsButton(),
                            const SizedBox(height: 12),
                            _buildBackgroundButton(),
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
  }

  Widget _buildHeader() {
    return Container(
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
    );
  }

  Widget _buildConnectivitySection() {
    return Row(
      children: [
        Expanded(
          child: QuickToggleButton(
            icon: Icons.wifi,
            label: 'Wi-Fi',
            active: _wifiEnabled,
            onTap: () async {
              await SystemControls.toggleWifi(!_wifiEnabled);
              setState(() => _wifiEnabled = !_wifiEnabled);
              if (mounted) Navigator.of(context).pop();
            },
          ),
        ),
        const SizedBox(width: 8),
        SmallToggleButton(
          icon: Icons.bluetooth,
          active: _bluetoothEnabled,
          onTap: () async {
            await SystemControls.toggleBluetooth(!_bluetoothEnabled);
            setState(() => _bluetoothEnabled = !_bluetoothEnabled);
            if (mounted) Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  Widget _buildModeSection() {
    return Row(
      children: [
        Expanded(
          child: QuickToggleButton(
            icon: Icons.airplanemode_active,
            label: 'Airplane',
            active: _airplaneMode,
            onTap: () async {
              await SystemControls.toggleAirplaneMode(!_airplaneMode);
              setState(() => _airplaneMode = !_airplaneMode);
              if (mounted) Navigator.of(context).pop();
            },
          ),
        ),
        const SizedBox(width: 8),
        SmallToggleButton(
          icon: Icons.dark_mode,
          active: false,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildBrightnessControl() {
    return Container(
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
              onChanged: (value) async {
                await SystemControls.setBrightness(value);
                setState(() => _brightness = value);
              },
              activeColor: Colors.white,
              inactiveColor: Colors.grey.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeControl() {
    return Container(
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
              onChanged: (value) async {
                await SystemControls.setVolume(value);
                setState(() => _volume = value);
              },
              activeColor: Colors.white,
              inactiveColor: Colors.grey.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsButton() {
    return SizedBox(
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
        onPressed: () async {
          Navigator.of(context).pop();
          await SystemControls.openSettings();
        },
      ),
    );
  }

  Widget _buildBackgroundButton() {
    return SizedBox(
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
          _pickAndSetBackground();
        },
      ),
    );
  }
}