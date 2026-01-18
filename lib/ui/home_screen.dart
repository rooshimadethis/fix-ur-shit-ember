import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ember_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import 'settings_screen.dart';
import 'widgets/steep_timer.dart';
import 'widgets/liquid_fill_background.dart';
import 'widgets/glass_card.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _colorDebounce;

  static const List<Map<String, dynamic>> _commonColors = [
    {'name': 'Ember', 'color': Color(0xFFFF9F1C)},
    {'name': 'Copper', 'color': Color(0xFFD2691E)},
    {'name': 'Rose Gold', 'color': Color(0xFFB76E79)},
    {'name': 'Gold', 'color': Color(0xFFFFD700)},
    {'name': 'Sage', 'color': Color(0xFF848B79)},
    {'name': 'Sandstone', 'color': Color(0xFFC2B280)},
    {'name': 'White', 'color': Color(0xFFFFFFFF)},
    {'name': 'Red', 'color': Color(0xFFFF0000)},
    {'name': 'Blue', 'color': Color(0xFF0000FF)},
    {'name': 'Green', 'color': Color(0xFF00FF00)},
  ];

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  Future<void> _checkPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location, // Required for Android 11 and lower scanning
    ].request();

    if (mounted && !kDebugMode) {
      Provider.of<EmberService>(context, listen: false).startScan();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _colorDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emberService = Provider.of<EmberService>(context);
    final settingsService = Provider.of<SettingsService>(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "EMBER CONTROL",
          style: TextStyle(
            fontSize: 14,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        actions: [
          Semantics(
            label: "Open settings",
            button: true,
            child: IconButton(
              icon: const Icon(Icons.settings_rounded, color: Colors.white70),
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ),
          Semantics(
            label: "Show app information and disclaimer",
            button: true,
            child: IconButton(
              icon: const Icon(Icons.info_rounded, color: Colors.white70),
              onPressed: () {
                HapticFeedback.mediumImpact();
                _showInfoDialog(context);
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
            ),
          ),

          // Liquid Level Wave Visualization (disabled with reduce motion)
          if (settingsService.showLiquidAnimation && !reduceMotion)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 1000),
                  opacity: emberService.isConnected ? 1.0 : 0.0,
                  child: LiquidFillBackground(
                    fillLevel: emberService.normalizedLiquidLevel,
                    baseColor:
                        (emberService.isHeating || emberService.isPerfect)
                        ? AppTheme.emberOrange
                        : Colors.blue,
                  ),
                ),
              ),
            ),

          // Heating/Cooling Gradient Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.5,
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeInOut,
                opacity: (emberService.isConnected)
                    ? 1.0
                    : 0.0, // Show when connected or debug
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: (emberService.isHeating || emberService.isPerfect)
                          ? [
                              Colors.red.withValues(alpha: 0.4),
                              AppTheme.emberOrange.withValues(alpha: 0.2),
                              Colors.transparent,
                            ]
                          : [
                              Colors.blue.withValues(alpha: 0.4),
                              Colors.cyan.withValues(alpha: 0.2),
                              Colors.transparent,
                            ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Paper Texture Overlay
          Positioned.fill(
            child: Opacity(
              opacity: 0.10,
              child: Image.asset(
                'assets/paper_texture.png',
                fit: BoxFit.cover,
                color: const Color(0xFFF8F2E6),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: emberService.isConnected
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (emberService.isConnected)
                            const SizedBox(height: 48),

                          // Status / Connection
                          if (!emberService.isConnected) ...[
                            _buildBluetoothWarning(emberService),
                            _buildScanButton(emberService),
                          ] else ...[
                            _buildTemperatureDisplay(
                              emberService,
                              settingsService,
                            ),
                            const SizedBox(height: 40),
                            _buildControls(emberService, settingsService),
                            if (settingsService.showSteepTimer) ...[
                              const SizedBox(height: 24),
                              const SteepTimer(),
                            ],

                            // Debug Controls (Only in Mock/Debug Mode & if enabled in Settings)
                            if (kDebugMode &&
                                emberService.isMock &&
                                settingsService.showDebugControls) ...[
                              const SizedBox(height: 24),
                              _buildDebugControls(emberService),
                            ],
                          ],
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Loading Overlay if scanning
          if (emberService.isScanning)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: const Center(
                  child: CircularProgressIndicator(color: AppTheme.emberOrange),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScanButton(EmberService service) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: "Scan for nearby Ember mugs",
            button: true,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                service.startScan();
              },
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.emberOrange.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.bluetooth_searching_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                          SizedBox(height: 10),
                          Text(
                            "CONNECT MUG",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Tap to search for nearby mugs.\nMake sure your mug is powered on and near your device.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                height: 1.5,
                fontSize: 14,
              ),
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                service.enableMockMode();
              },
              child: const Text(
                "DEBUG: Enable Mock Mode",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBluetoothWarning(EmberService service) {
    if (service.adapterState == BluetoothAdapterState.on || service.isMock) {
      return const SizedBox.shrink();
    }

    String title = "Bluetooth is Off";
    String subtitle = "Enable Bluetooth to connect your mug";
    IconData icon = Icons.bluetooth_disabled_rounded;
    Color accentColor = Colors.orangeAccent;

    if (service.adapterState == BluetoothAdapterState.unauthorized) {
      title = "Permissions Needed";
      subtitle = "Bluetooth permissions are required to scan";
      icon = Icons.gpp_maybe_rounded;
    } else if (service.adapterState == BluetoothAdapterState.unavailable) {
      title = "Bluetooth Unavailable";
      subtitle = "Your device does not support Bluetooth";
      icon = Icons.bluetooth_disabled_rounded;
      accentColor = Colors.redAccent;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: accentColor, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemperatureDisplay(
    EmberService service,
    SettingsService settings,
  ) {
    final tempCelsius = service.currentTemp ?? 0.0;
    final displayTemp = settings.displayTemp(tempCelsius);
    final batteryLevel = service.batteryLevel;
    final isCharging = service.isCharging == true;

    return Semantics(
      label: "Current mug temperature information",
      child: Column(
        children: [
          if (service.isEmpty)
            Semantics(
              label: "Mug is empty",
              child: const Text(
                "EMPTY",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
            ),
          Semantics(
            label:
                "Current Temperature: ${service.currentTemp != null ? displayTemp.toStringAsFixed(settings.temperatureUnit == TemperatureUnit.fahrenheit ? 0 : 1) : "unknown"} ${settings.unitSymbol}",
            child: Text(
              service.currentTemp != null
                  ? "${displayTemp.toStringAsFixed(settings.temperatureUnit == TemperatureUnit.fahrenheit ? 0 : 1)}${settings.unitSymbol}"
                  : "--${settings.unitSymbol}",
              textScaler: TextScaler.linear(
                MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.5),
              ),
              style: const TextStyle(
                fontSize: 80,
                fontWeight: FontWeight.w300,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          const Text(
            "Current Temperature",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (batteryLevel != null) ...[
            const SizedBox(height: 10),
            Semantics(
              label:
                  "Battery level: $batteryLevel percent${isCharging ? ", charging" : ""}",
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCharging
                        ? Icons.battery_charging_full_rounded
                        : Icons.battery_std_rounded,
                    color: batteryLevel < 20
                        ? Colors.redAccent
                        : Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "$batteryLevel%",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  double? _draggedTemp;

  Widget _buildControls(EmberService service, SettingsService settings) {
    // Check if heating is effectively on
    bool isHeatingOn = (service.targetTemp ?? 0) > 1.0;

    // Get current target temp in Celsius (device uses Celsius)
    // If off, show the last valid target temp so the slider doesn't jump to 0 or min
    final targetCelsius = isHeatingOn
        ? (service.targetTemp ?? 50.0)
        : (service.lastValidTargetTemp ?? 57.0);

    // Convert to display unit
    final displayTemp = settings.displayTemp(targetCelsius);

    // If user is dragging using local state, otherwise use real value
    // If not heating, ignore dragged temp
    final sliderValue = (isHeatingOn ? _draggedTemp : null) ?? displayTemp;

    // Check if data is loaded to enable controls
    final bool isReady = service.currentTemp != null;

    return GlassCard(
      child: Column(
        children: [
          const Text(
            "Target Temperature",
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            "${sliderValue.toStringAsFixed(settings.temperatureUnit == TemperatureUnit.celsius ? 1 : 0)}${settings.unitSymbol}",
            textScaler: TextScaler.linear(
              MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.5),
            ),
            style: TextStyle(
              color: isHeatingOn ? Colors.white : Colors.white60,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              shadows: isHeatingOn
                  ? [
                      const Shadow(
                        color: Colors.black26,
                        offset: Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          Semantics(
            label: "Target temperature slider",
            value:
                "${sliderValue.toStringAsFixed(settings.temperatureUnit == TemperatureUnit.celsius ? 1 : 0)} degrees",
            enabled: isHeatingOn,
            onIncrease: () {
              if (isHeatingOn && sliderValue < settings.maxTemp) {
                final increment =
                    settings.temperatureUnit == TemperatureUnit.celsius
                    ? 0.5
                    : 1.0;
                final newValue = sliderValue + increment;
                service.setTargetTemp(settings.toDeviceTemp(newValue));
                HapticFeedback.lightImpact();
              }
            },
            onDecrease: () {
              if (isHeatingOn && sliderValue > settings.minTemp) {
                final decrement =
                    settings.temperatureUnit == TemperatureUnit.celsius
                    ? 0.5
                    : 1.0;
                final newValue = sliderValue - decrement;
                service.setTargetTemp(settings.toDeviceTemp(newValue));
                HapticFeedback.lightImpact();
              }
            },
            child: SliderTheme(
              data: SliderTheme.of(
                context,
              ).copyWith(tickMarkShape: SliderTickMarkShape.noTickMark),
              child: Slider(
                value: sliderValue.clamp(settings.minTemp, settings.maxTemp),
                min: settings.minTemp,
                max: settings.maxTemp,
                divisions: settings.temperatureUnit == TemperatureUnit.celsius
                    ? ((settings.maxTemp - settings.minTemp) * 2)
                          .toInt() // 0.5° steps for Celsius
                    : (settings.maxTemp - settings.minTemp)
                          .toInt(), // 1° steps for Fahrenheit
                activeColor: isHeatingOn
                    ? AppTheme.emberOrange
                    : Colors.grey.withValues(alpha: 0.3),
                inactiveColor: isHeatingOn
                    ? Colors.white12
                    : Colors.white.withValues(alpha: 0.05),
                thumbColor: isHeatingOn
                    ? AppTheme.emberOrange
                    : Colors.grey.withValues(alpha: 0.5),
                onChanged: isHeatingOn
                    ? (val) {
                        final step =
                            settings.temperatureUnit == TemperatureUnit.celsius
                            ? 0.5
                            : 1.0;
                        if ((sliderValue / step).round() !=
                            (val / step).round()) {
                          HapticFeedback.lightImpact(); // More "mechanical" feel
                        }
                        setState(() {
                          _draggedTemp = val;
                        });
                      }
                    : null, // Disable slider when off
                onChangeEnd: isHeatingOn
                    ? (val) {
                        HapticFeedback.mediumImpact(); // Solid "set" feel
                        // Convert display temp back to Celsius for the device
                        final celsiusTemp = settings.toDeviceTemp(val);
                        service.setTargetTemp(celsiusTemp);

                        // Clear local drag state after a short delay to allow service to update
                        setState(() {
                          _draggedTemp = null;
                        });
                      }
                    : null,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${settings.minTemp.toStringAsFixed(settings.temperatureUnit == TemperatureUnit.celsius ? 1 : 0)}${settings.unitSymbol}",
                style: TextStyle(
                  color: isHeatingOn ? Colors.white60 : Colors.white38,
                  fontSize: 16,
                ),
              ),
              Text(
                "${settings.maxTemp.toStringAsFixed(settings.temperatureUnit == TemperatureUnit.celsius ? 1 : 0)}${settings.unitSymbol}",
                style: TextStyle(
                  color: isHeatingOn ? Colors.white60 : Colors.white38,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: _buildColorButton(service, isReady)),
              const SizedBox(width: 12),
              Expanded(child: _buildPowerButton(service, enabled: isReady)),
            ],
          ),
          if (settings.presetCount > 0) ...[
            const SizedBox(height: 16),
            _buildPresets(service, settings, isHeatingOn),
          ],
        ],
      ),
    );
  }

  Widget _buildPresets(
    EmberService service,
    SettingsService settings,
    bool isHeatingOn,
  ) {
    final count = settings.presetCount;
    final presets = settings.presets.take(count).toList();
    if (presets.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        // Calculate item width for 2 columns
        final itemWidth = (constraints.maxWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          alignment: WrapAlignment.center,
          children: presets.asMap().entries.map((entry) {
            return SizedBox(
              width: itemWidth,
              child: AspectRatio(
                aspectRatio: 2.2,
                child: _buildPresetChip(
                  context,
                  service,
                  settings,
                  entry.key,
                  entry.value,
                  isHeatingOn,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPresetChip(
    BuildContext context,
    EmberService service,
    SettingsService settings,
    int index,
    Map<String, dynamic> preset,
    bool enabled,
  ) {
    final name = preset['name'] as String;
    final icon = preset['icon'] as String? ?? '🌡️';
    final tempCelsius = (preset['temp'] as num).toDouble();
    final displayTemp = settings.displayTemp(tempCelsius);
    final isSelected =
        enabled &&
        service.targetTemp != null &&
        (service.targetTemp! - tempCelsius).abs() < 0.5;

    return Semantics(
      label:
          "Preset $name. Icon $icon. Temp ${displayTemp.toStringAsFixed(1)} degrees.",
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                service.setTargetTemp(tempCelsius);
              }
            : null,
        onLongPress: () =>
            _showPresetEditDialog(context, settings, index, preset),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.emberOrange.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppTheme.emberOrange
                  : Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                icon,
                style: const TextStyle(fontSize: 24), // Larger emoji
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${displayTemp.toStringAsFixed(settings.temperatureUnit == TemperatureUnit.celsius ? 1 : 0)}${settings.unitSymbol}",
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPresetEditDialog(
    BuildContext context,
    SettingsService settings,
    int index,
    Map<String, dynamic> preset,
  ) {
    HapticFeedback.mediumImpact();
    final TextEditingController nameController = TextEditingController(
      text: preset['name'],
    );
    final TextEditingController iconController = TextEditingController(
      text: preset['icon'] as String? ?? '🌡️',
    );
    // Convert storage Celsius to user display unit
    double currentCelsius = (preset['temp'] as num).toDouble();
    double currentDisplay = settings.displayTemp(currentCelsius);

    // Initial check for range clamping in display units
    double minDisplay = settings.minTemp;
    double maxDisplay = settings.maxTemp;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              title: const Text(
                "Edit Preset",
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: TextField(
                            controller: iconController,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                            ),
                            maxLength: 1,
                            decoration: InputDecoration(
                              counterText: "",
                              labelText: "Icon",
                              labelStyle: const TextStyle(
                                color: Colors.white70,
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                              focusedBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: AppTheme.emberOrange,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: nameController,
                            style: const TextStyle(color: Colors.white),
                            maxLength: 12,
                            decoration: InputDecoration(
                              labelText: "Preset Name",
                              labelStyle: const TextStyle(
                                color: Colors.white70,
                              ),
                              counterStyle: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                              focusedBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: AppTheme.emberOrange,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Temperature",
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        Text(
                          "${currentDisplay.toStringAsFixed(settings.temperatureUnit == TemperatureUnit.celsius ? 1 : 0)}${settings.unitSymbol}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppTheme.emberOrange,
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: currentDisplay.clamp(minDisplay, maxDisplay),
                        min: minDisplay,
                        max: maxDisplay,
                        divisions:
                            settings.temperatureUnit == TemperatureUnit.celsius
                            ? ((maxDisplay - minDisplay) * 2).toInt()
                            : (maxDisplay - minDisplay).toInt(),
                        onChanged: (val) {
                          final step =
                              settings.temperatureUnit ==
                                  TemperatureUnit.celsius
                              ? 0.5
                              : 1.0;
                          if ((currentDisplay / step).round() !=
                              (val / step).round()) {
                            HapticFeedback.lightImpact();
                          }
                          setState(() {
                            currentDisplay = val;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    // Validate preset name is not empty
                    final trimmedName = nameController.text.trim();
                    if (trimmedName.isEmpty) {
                      // Show error feedback
                      HapticFeedback.heavyImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Preset name cannot be empty'),
                          duration: Duration(seconds: 2),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    // Convert back to Celsius for storage
                    double newCelsius = settings.toDeviceTemp(currentDisplay);
                    settings.updatePreset(
                      index,
                      trimmedName,
                      iconController.text.isNotEmpty
                          ? iconController.text
                          : '🌡️',
                      newCelsius,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "Save",
                    style: TextStyle(color: AppTheme.emberOrange),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildColorButton(EmberService service, bool enabled) {
    return Semantics(
      label:
          "Set mug LED color. Current color: ${_colorName(service.userLedColor)}",
      button: true,
      enabled: enabled,
      hint: enabled ? "Tap to open color picker" : null,
      child: GestureDetector(
        onTap: enabled ? () => _showColorPicker(service) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: service.userLedColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.9),
                    width: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "COLOR",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showColorPicker(EmberService service) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.80,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                "MUG LED COLOR",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "PRESETS",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                          ),
                      itemCount: _commonColors.length,
                      itemBuilder: (context, index) {
                        final item = _commonColors[index];
                        final isSelected =
                            service.userLedColor == item['color'];
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            service.setLedColor(item['color']);
                            Navigator.pop(context);
                          },
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                padding: const EdgeInsets.all(2),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: item['color'],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      "CUSTOM COLOR",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ColorPicker(
                      pickerColor: service.userLedColor,
                      onColorChanged: (color) {
                        _colorDebounce?.cancel();
                        _colorDebounce = Timer(
                          const Duration(milliseconds: 200),
                          () {
                            service.setLedColor(color);
                          },
                        );
                      },
                      pickerAreaHeightPercent: 0.7,
                      enableAlpha: false,
                      displayThumbColor: true,
                      labelTypes: const [],
                      paletteType: PaletteType.hsvWithHue,
                      pickerAreaBorderRadius: BorderRadius.circular(20),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.emberOrange.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.emberOrange.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              "CONFIRM",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerButton(EmberService service, {bool enabled = true}) {
    bool isHeatingOn = (service.targetTemp ?? 0) > 1.0;

    final buttonColor = isHeatingOn
        ? const Color(0xFFE64A19) // Bright red-orange for OFF
        : AppTheme.emberOrange; // Ember orange for HEAT
    final displayColor = enabled ? buttonColor : Colors.grey;

    return Semantics(
      label: isHeatingOn ? "Turn heating off" : "Turn heating on",
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled
            ? () {
                HapticFeedback.mediumImpact();
                service.toggleHeating();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: displayColor.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isHeatingOn
                    ? Icons.power_settings_new_rounded
                    : Icons.local_fire_department_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                isHeatingOn ? "OFF" : "HEAT",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDebugControls(EmberService service) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bug_report_rounded,
                color: Colors.redAccent,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                "DEBUG CONTROLS (MOCK ONLY)",
                style: TextStyle(
                  color: Colors.red.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Fill Level",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              Text(
                "${service.liquidLevel ?? 0}",
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
          Slider(
            value: (service.liquidLevel ?? 0).toDouble(),
            min: 0,
            max: 30,
            activeColor: Colors.redAccent,
            onChanged: (val) {
              if (val.toInt() != (service.liquidLevel ?? 0)) {
                HapticFeedback.selectionClick();
                service.setMockLiquidLevel(val.toInt());
              }
            },
          ),
          const SizedBox(height: 8),
          const Text(
            "Liquid State",
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [0, 1, 2, 3, 4, 5, 6, 7].map((state) {
              final isSelected = service.liquidState == state;
              return GestureDetector(
                onTap: () => service.setMockLiquidState(state),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.redAccent
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    service.getLiquidStateName(state),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF2C5364).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Important Info",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const Text(
                        "• Initialize First: The mug must be set up in the official Ember app at least once after a reset to enable control.\n\n"
                        "• Avoid Interference: Fully close the official Ember app before using this one. If connection issues persist, 'Forget' the mug in your Bluetooth settings.\n\n"
                        "• Troubleshooting: If the mug refuses to connect, perform a factory reset (hold the power button on the bottom for ~7 seconds until it flashes red) and then pair again.",
                        style: TextStyle(color: Colors.white70, height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text(
                        "DISCLAIMER\n\n"
                        "This software is provided \"as is\", without warranty of any kind. The developers are not affiliated with Ember®. Use this application at your own risk. The user assumes all responsibility for any potential damage to their device, mug, or voiding of warranties.",
                        style: TextStyle(
                          color: Colors.white38,
                          height: 1.3,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).pop();
                },
                child: const Text(
                  "Got it",
                  style: TextStyle(color: AppTheme.emberOrange, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _colorName(Color color) {
    // Check against common colors
    for (final item in _commonColors) {
      if (item['color'] == color) {
        return item['name'] as String;
      }
    }
    // Fallback to RGB description for custom colors
    return 'Custom color: red ${color.r}, green ${color.g}, blue ${color.b}';
  }
}
