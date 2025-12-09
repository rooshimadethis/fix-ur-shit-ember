import 'dart:ui';
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
      Permission.location, // For Android < 12
    ].request();

    if (mounted) {
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
                             onPressed: () => Navigator.of(context).push(
                               MaterialPageRoute(builder: (_) => const SettingsScreen()),
                             ),
                           ),
                           IconButton(
                             icon: const Icon(Icons.info_outline, color: Colors.white60),
                             onPressed: () => _showInfoDialog(context),
                           ),
                         ],
                       ),
                     ],
                   ),
                   const Spacer(),
                   
                   // Status / Connection
                   if (!emberService.isConnected) ...[
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
            onTap: service.startScan,
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
          "${displayTemp.toStringAsFixed(1)}${settings.unitSymbol}",
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
    // Get current target temp in Celsius (device uses Celsius)
    final targetCelsius = service.targetTemp ?? 50.0;
    // Convert to display unit
    final displayTemp = settings.displayTemp(targetCelsius);
    
    // If user is dragging using local state, otherwise use real value
    final sliderValue = _draggedTemp ?? displayTemp;
    
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
          const SizedBox(height: 10),
          Slider(
            value: sliderValue.clamp(settings.minTemp, settings.maxTemp),
            min: settings.minTemp,
            max: settings.maxTemp,
            activeColor: AppTheme.emberOrange,
            inactiveColor: Colors.white12,
            onChanged: (val) {
               setState(() {
                 _draggedTemp = val;
               });
            },
            onChangeEnd: (val) {
               // Convert display temp back to Celsius for the device
               final celsiusTemp = settings.toDeviceTemp(val);
               service.setTargetTemp(celsiusTemp); 
               
               // Clear local drag state after a short delay to allow service to update
               setState(() {
                 _draggedTemp = null;
               });
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${settings.minTemp.toStringAsFixed(0)}${settings.unitSymbol}", style: const TextStyle(color: Colors.white38)),
              Text("${settings.maxTemp.toStringAsFixed(0)}${settings.unitSymbol}", style: const TextStyle(color: Colors.white38)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
               _colorButton(service, Colors.red),
               _colorButton(service, Colors.green),
               _colorButton(service, Colors.blue),
               _colorButton(service, Colors.amber),
            ],
          )
        ],
      ),
    );
  }
  
  Widget _colorButton(EmberService service, Color color) {
    return GestureDetector(
      onTap: () => service.setLedColor(color),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
             BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))
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
              const Text(
                "• Initialize First: The mug must be set up in the official Ember app at least once after a reset to enable control.\n\n"
                "• Avoid Interference: Fully close the official Ember app before using this one. If connection issues persist, 'Forget' the mug in your Bluetooth settings.\n\n"
                "• Troubleshooting: If the mug refuses to connect, perform a factory reset (hold the power button on the bottom for ~7 seconds until it flashes red) and then pair again.",
                style: TextStyle(color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Got it", style: TextStyle(color: AppTheme.emberOrange, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
