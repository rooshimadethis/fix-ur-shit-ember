import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ember_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _debugMockConnection = false;

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
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
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
                opacity: (emberService.isConnected || _debugMockConnection) ? 1.0 : 0.0, // Show when connected or debug
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
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       const Text(
                         "EMBER CONTROL",
                         style: TextStyle(
                           fontSize: 14,
                           letterSpacing: 2,
                           fontWeight: FontWeight.w600,
                           color: Colors.white60,
                         ),
                       ),
                       Row(
                         children: [
                           IconButton(
                             icon: const Icon(Icons.settings_outlined, color: Colors.white60),
                             onPressed: () {
                               HapticFeedback.mediumImpact();
                               Navigator.of(context).push(
                               MaterialPageRoute(builder: (_) => const SettingsScreen()),
                               );
                             },
                           ),
                           IconButton(
                             icon: const Icon(Icons.info_outline, color: Colors.white60),
                             onPressed: () {
                               HapticFeedback.mediumImpact();
                               _showInfoDialog(context);
                             },
                           ),
                         ],
                       ),
                     ],
                   ),
                   const Spacer(),
                   
                   // Status / Connection
                   if (!emberService.isConnected && !_debugMockConnection) ...[
                     _buildScanButton(emberService),
                   ] else ...[
                     _buildTemperatureDisplay(emberService, settingsService),
                     const SizedBox(height: 40),
                     _buildControls(emberService, settingsService),
                   ],
                   
                   const Spacer(),
                ],
              ),
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
                   )
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
                        Icon(Icons.bluetooth_searching, color: Colors.white, size: 40),
                        SizedBox(height: 10),
                        Text("CONNECT MUG", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                color: Colors.white54,
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
                setState(() {
                  _debugMockConnection = true;
                });
              },
              child: const Text("DEBUG: Show Controls", style: TextStyle(color: Colors.red)),
            ),
          ],
        ],
      ),
    );
  }



  Widget _buildTemperatureDisplay(EmberService service, SettingsService settings) {
    final tempCelsius = service.currentTemp ?? 0.0;
    final displayTemp = settings.displayTemp(tempCelsius);
    final batteryLevel = service.batteryLevel;
    final isCharging = service.isCharging == true;
    
    return Column(
      children: [
        if (service.isEmpty)
          const Text(
            "EMPTY",
            style: TextStyle(
              color: Colors.white54,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
        Text(
          service.currentTemp != null
              ? "${displayTemp.toStringAsFixed(settings.temperatureUnit == TemperatureUnit.fahrenheit ? 0 : 1)}${settings.unitSymbol}"
              : "--${settings.unitSymbol}",
          style: const TextStyle(
            fontSize: 80,
            fontWeight: FontWeight.w200,
            color: Colors.white,
          ),
        ),
        const Text(
          "Current Temperature",
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
        if (batteryLevel != null) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCharging ? Icons.battery_charging_full : Icons.battery_std,
                color: batteryLevel < 20 ? Colors.redAccent : Colors.white70,
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
        ],
      ],
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
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          const Text("Target Temperature", style: TextStyle(color: Colors.white70)),
          Text(
            "${sliderValue.toStringAsFixed(0)}${settings.unitSymbol}",
            style: TextStyle(
              color: isHeatingOn ? Colors.white : Colors.white38, // Dim text if off
              fontSize: 32,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Slider(
            value: sliderValue.clamp(settings.minTemp, settings.maxTemp),
            min: settings.minTemp,
            max: settings.maxTemp,
            activeColor: isHeatingOn ? AppTheme.emberOrange : Colors.grey.withValues(alpha: 0.3),
            inactiveColor: isHeatingOn ? Colors.white12 : Colors.white.withValues(alpha: 0.05),
            thumbColor: isHeatingOn ? AppTheme.emberOrange : Colors.grey.withValues(alpha: 0.5),
            onChanged: isHeatingOn ? (val) {
               if (sliderValue.round() != val.round()) {
                 HapticFeedback.selectionClick();
               }
               setState(() {
                 _draggedTemp = val;
               });
            } : null, // Disable slider when off
            onChangeEnd: isHeatingOn ? (val) {
               // Convert display temp back to Celsius for the device
               final celsiusTemp = settings.toDeviceTemp(val);
               service.setTargetTemp(celsiusTemp); 
               
               // Clear local drag state after a short delay to allow service to update
               setState(() {
                 _draggedTemp = null;
               });
            } : null,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${settings.minTemp.toStringAsFixed(0)}${settings.unitSymbol}", 
                style: TextStyle(color: isHeatingOn ? Colors.white38 : Colors.white12)),
              Text("${settings.maxTemp.toStringAsFixed(0)}${settings.unitSymbol}", 
                style: TextStyle(color: isHeatingOn ? Colors.white38 : Colors.white12)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
               _colorButton(service, Colors.red, enabled: isHeatingOn),
               _colorButton(service, Colors.green, enabled: isHeatingOn),
               _colorButton(service, Colors.blue, enabled: isHeatingOn),
               _colorButton(service, Colors.amber, enabled: isHeatingOn),
            ],
          ),
          const SizedBox(height: 24),
          _buildPowerButton(service, enabled: isReady),
        ],
      ),
    );
  }
  
  Widget _colorButton(EmberService service, Color color, {bool enabled = true}) {
    return GestureDetector(
      onTap: enabled ? () {
        HapticFeedback.mediumImpact();
        service.setLedColor(color);
      } : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled ? color : color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          boxShadow: enabled ? [
             BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))
          ] : [],
        ),
      ),
    );
  }

  Widget _buildPowerButton(EmberService service, {bool enabled = true}) {
    bool isHeatingOn = (service.targetTemp ?? 0) > 1.0;
    
    final buttonColor = isHeatingOn ? Colors.red : AppTheme.emberOrange;
    final displayColor = enabled ? buttonColor : Colors.grey;
    
    return GestureDetector(
      onTap: enabled ? () {
        HapticFeedback.mediumImpact();
        service.toggleHeating();
      } : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: displayColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: displayColor.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: enabled ? [
            BoxShadow(
              color: displayColor.withValues(alpha: 0.1),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ] : []
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isHeatingOn ? Icons.power_settings_new : Icons.local_fire_department,
              color: displayColor,
            ),
            const SizedBox(width: 12),
            Text(
              isHeatingOn ? "TURN OFF" : "HEAT UP",
              style: TextStyle(
                color: displayColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF2C5364).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
              )
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
              Expanded(
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
                        style: TextStyle(color: Colors.white38, height: 1.3, fontSize: 12),
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
                child: const Text("Got it", style: TextStyle(color: AppTheme.emberOrange, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
