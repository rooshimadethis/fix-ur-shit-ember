import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emberService = Provider.of<EmberService>(context);
    final settingsService = Provider.of<SettingsService>(context);

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
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white70),
            onPressed: () {
              HapticFeedback.mediumImpact();
              _showInfoDialog(context);
            },
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

          // Liquid Level Wave Visualization
          if (settingsService.showLiquidAnimation)
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
              opacity: 0.15,
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
                  physics: const NeverScrollableScrollPhysics(),
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
          GestureDetector(
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
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
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
                          Icons.bluetooth_searching,
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
              fontSize: 16,
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
                        ? Icons.battery_charging_full
                        : Icons.battery_std,
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
            "${sliderValue.toStringAsFixed(0)}${settings.unitSymbol}",
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
            value: "${sliderValue.toStringAsFixed(0)} degrees",
            enabled: isHeatingOn,
            onIncrease: () {
              if (isHeatingOn && sliderValue < settings.maxTemp) {
                final newValue = sliderValue + 1;
                service.setTargetTemp(settings.toDeviceTemp(newValue));
                HapticFeedback.lightImpact();
              }
            },
            onDecrease: () {
              if (isHeatingOn && sliderValue > settings.minTemp) {
                final newValue = sliderValue - 1;
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
                divisions: (settings.maxTemp - settings.minTemp).toInt(),
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
                        if (sliderValue.round() != val.round()) {
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
                "${settings.minTemp.toStringAsFixed(0)}${settings.unitSymbol}",
                style: TextStyle(
                  color: isHeatingOn ? Colors.white60 : Colors.white38,
                ),
              ),
              Text(
                "${settings.maxTemp.toStringAsFixed(0)}${settings.unitSymbol}",
                style: TextStyle(
                  color: isHeatingOn ? Colors.white60 : Colors.white38,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: _buildColorButton(service, isHeatingOn)),
              const SizedBox(width: 12),
              Expanded(child: _buildPowerButton(service, enabled: isReady)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorButton(EmberService service, bool enabled) {
    return Semantics(
      label: "Change mug LED color",
      button: true,
      enabled: enabled,
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
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
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
        height: MediaQuery.of(context).size.height * 0.75,
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
                    const SizedBox(height: 40),
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

    final buttonColor = isHeatingOn ? Colors.deepOrange : AppTheme.emberOrange;
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
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isHeatingOn
                    ? Icons.power_settings_new
                    : Icons.local_fire_department,
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
              const Icon(Icons.bug_report, color: Colors.redAccent, size: 16),
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
            onChanged: (val) => service.setMockLiquidLevel(val.toInt()),
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
}
