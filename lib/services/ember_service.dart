import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'notification_service.dart';

class EmberService extends ChangeNotifier {
  BluetoothDevice? _connectedDevice;

  BluetoothCharacteristic? _currentTempChar;
  BluetoothCharacteristic? _targetTempChar;
  BluetoothCharacteristic? _ledChar;
  BluetoothCharacteristic? _liquidLevelChar;
  BluetoothCharacteristic? _liquidStateChar;
  BluetoothCharacteristic? _batteryChar;
  // ignore: unused_field
  BluetoothCharacteristic? _pushEventChar;

  bool _isScanning = false;
  bool get isScanning => _isScanning;
  
  bool get isConnected => _connectedDevice != null;
  
  double? _currentTemp;
  double? get currentTemp => _currentTemp;

  double? _targetTemp;
  double? get targetTemp => _targetTemp;

  double? _lastValidTargetTemp;
  double? get lastValidTargetTemp => _lastValidTargetTemp;



  int? _liquidLevel;
  int? get liquidLevel => _liquidLevel;

  int? _liquidState; // 0=Standby, 1=Empty, 2=Filling, 3=Cold, 4=Cooling, 5=Heating, 6=Perfect, 7=Warm
  int? get liquidState => _liquidState;
  
  bool get isEmpty => _liquidState == 1; // LiquidState.EMPTY = 1
  bool get isHeating => _liquidState == 5; // LiquidState.HEATING = 5
  bool get isPerfect => _liquidState == 6; // LiquidState.PERFECT = 6

  int? _batteryLevel;
  int? get batteryLevel => _batteryLevel;

  bool? _isCharging;
  bool? get isCharging => _isCharging;


  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;

  void startScan() async {
    if (_isScanning) return;
    
    debugPrint("EmberService: Starting scan...");
    
    // Check adapter state
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      debugPrint("EmberService: Bluetooth is not on. Waiting for it...");
      try {
        await FlutterBluePlus.adapterState.where((s) => s == BluetoothAdapterState.on).first.timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint("EmberService: Bluetooth failed to turn on or timeout: $e");
        // Depending on platform, we can't force turn it on.
      }
    }

    _isScanning = true;
    notifyListeners();

    try {
      // Remove service UUID filter to see if it helps find the device
      await FlutterBluePlus.startScan(
        // withServices: [Guid(EmberConstants.serviceUuid)], // Removed filter
        timeout: const Duration(seconds: 15),
      );
      debugPrint("EmberService: Scan started. Listening for results...");
      
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          String name = result.device.platformName;
          String advName = result.advertisementData.advName;
          
          if (name.isEmpty) name = advName;
          
          debugPrint("EmberService: Found device: $name (${result.device.remoteId}) RSSI: ${result.rssi}");
          
          if (name.toLowerCase().contains("ember")) {
             debugPrint("EmberService: FOUND EMBER! Connecting to $name...");
             _connectToFoundDevice(result.device);
             break;
          }
        }
      });
      
    } catch (e) {
      debugPrint("EmberService: Error scanning: $e");
      _isScanning = false;
      notifyListeners();
    }
    
    // Auto stop scan after timeout handled by listen timeout or manual delay
    Future.delayed(const Duration(seconds: 15), () {
      if (_isScanning) {
        debugPrint("EmberService: Scan timed out.");
        stopScan();
      }
    });
  }

  Future<void> _connectToFoundDevice(BluetoothDevice device) async {
    // Stop scanning before connecting is crucial on Android
    await FlutterBluePlus.stopScan();
    _isScanning = false;
    notifyListeners();
    connect(device);
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    _isScanning = false;
    notifyListeners();
  }

  bool _isConnecting = false;

  Future<void> connect(BluetoothDevice device) async {
    if (_isConnecting || _connectedDevice != null) return;
    _isConnecting = true;
    
    debugPrint("EmberService: Attempting to connect to ${device.remoteId}...");
    try {
      // mtu: null prevents the auto-request of 512 bytes which causes Error 133 on some Android phones/devices
      await device.connect(autoConnect: false, mtu: null);
      debugPrint("EmberService: Connected!");
      _connectedDevice = device;
      
      // mtu: null prevents the auto-request of 512 bytes which causes Error 133 on some Android phones/devices
      await device.connect(autoConnect: false, mtu: null);
      debugPrint("EmberService: Connected!");
      _connectedDevice = device;
      
      // Listen to connection state
      _connectionSubscription = device.connectionState.listen((state) {
        debugPrint("EmberService: Connection state changed to: $state");
        if (state == BluetoothConnectionState.disconnected) {
            // Optional: attempt auto-reconnect logic here if desired, 
            // or just notify UI.
            debugPrint("EmberService: Device disconnected.");
            disconnect(); 
        }
      });

      // Discover services immediately
      debugPrint("EmberService: Discovering services...");
      try {
        await _discoverServices(device);
        debugPrint("EmberService: Service discovery completed successfully!");
        notifyListeners();
      } catch (e) {
        // Service discovery might fail due to Service Changed characteristic (GATT 133)
        // but the connection might still be valid. Check if we found the Ember service.
        debugPrint("EmberService: Service discovery error (might be Service Changed issue): $e");
        
        if (_targetTempChar != null || _ledChar != null) {
          debugPrint("EmberService: Found Ember characteristics despite error, continuing...");
          notifyListeners();
        } else {
          debugPrint("EmberService: Failed to find Ember service, disconnecting...");
          rethrow;
        }
      }
    } catch (e) {
      debugPrint("EmberService: Error connecting: $e");
      disconnect();
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    debugPrint("EmberService: Found ${services.length} services");
    
    // First pass: Find and store all characteristics
    for (var service in services) {
      debugPrint("EmberService: Service UUID: ${service.uuid}");
      
      // CRITICAL: Only process the Ember service to avoid system GATT characteristics
      // System characteristics like Service Changed (2a05) cause GATT_ERROR 133
      if (service.uuid.toString().toLowerCase() != EmberConstants.serviceUuid.toLowerCase()) {
        debugPrint("EmberService: Skipping non-Ember service: ${service.uuid}");
        continue;
      }
      
      debugPrint("EmberService: MATCHED Ember Service!");
      for (var characteristic in service.characteristics) {
        debugPrint("EmberService: Char UUID: ${characteristic.uuid}");
        
        String charUuidStr = characteristic.uuid.toString().toLowerCase();
        
        if (charUuidStr == EmberConstants.currentTempCharUuid.toLowerCase()) {
          debugPrint("EmberService: Found Current Temp Char (read-only)");
          _currentTempChar = characteristic;
        } else if (charUuidStr == EmberConstants.targetTempCharUuid.toLowerCase()) {
          debugPrint("EmberService: Found Target Temp Char");
          _targetTempChar = characteristic;
        } else if (charUuidStr == EmberConstants.ledCharUuid.toLowerCase()) {
          debugPrint("EmberService: Found LED Char");
          _ledChar = characteristic;
        } else if (charUuidStr == EmberConstants.liquidLevelCharUuid.toLowerCase()) {
          debugPrint("EmberService: Found Liquid Level Char");
          _liquidLevelChar = characteristic;
        } else if (charUuidStr == EmberConstants.liquidStateCharUuid.toLowerCase()) {
          debugPrint("EmberService: Found Liquid State Char");
          _liquidStateChar = characteristic;
        } else if (charUuidStr == EmberConstants.pushEventCharUuid.toLowerCase()) {
          debugPrint("EmberService: Found Push Event Char (notifications)");
          _pushEventChar = characteristic;
        } else if (charUuidStr == EmberConstants.batteryCharUuid.toLowerCase()) {
          debugPrint("EmberService: Found Battery Char");
          _batteryChar = characteristic;
        } else {
          debugPrint("EmberService: Skipping unknown Ember characteristic: ${characteristic.uuid}");
        }
      }
    }
    
    // Second pass: Perform operations
    // Subscribe to push events FIRST (matching Python implementation order)
    if (_pushEventChar != null) {
      await _setupNotifications(_pushEventChar!);
    }
    
    // Then read liquid state and level
    if (_liquidStateChar != null) {
      await _readLiquidState();
    }
    if (_liquidLevelChar != null) {
      await _readLiquidLevel();
    }
    
    // Then read current temperature
    if (_currentTempChar != null) {
      await _readCurrentTemp();
    }
    
    // Read battery
    if (_batteryChar != null) {
      await _readBatteryLevel();
    }

    // Restore saved target temperature
    if (_targetTempChar != null) {
      final prefs = await SharedPreferences.getInstance();
      final savedTemp = prefs.getDouble('ember_target_temp');
      if (savedTemp != null && savedTemp > 0) {
        debugPrint("EmberService: Restoring saved target temp: $savedTemp");
        _lastValidTargetTemp = savedTemp;
        await setTargetTemp(savedTemp);
      } else {
        // If no saved temp, read from device
        await _readTargetTemp();
      }
    }
  }

  Future<void> _setupNotifications(BluetoothCharacteristic characteristic) async {
    try {
      // Verify the characteristic supports notifications
      if (!characteristic.properties.notify && !characteristic.properties.indicate) {
        debugPrint("EmberService: Characteristic ${characteristic.uuid} does not support notifications!");
        return;
      }
      
      debugPrint("EmberService: Subscribing to notifications for ${characteristic.uuid}...");
      await characteristic.setNotifyValue(true);
      
      characteristic.onValueReceived.listen((value) {
         if (value.isNotEmpty) {
           // PUSH_EVENT sends event codes indicating what changed
           int eventCode = value[0];
           debugPrint("EmberService: Push event received: $eventCode");
           
           // Event codes from Python implementation:
           // 1: BATTERY_CHANGED, 2: CHARGER_CONNECTED, 3: CHARGER_DISCONNECTED
           // 4: TARGET_TEMPERATURE_CHANGED, 5: DRINK_TEMPERATURE_CHANGED
           // 6: AUTH_INFO_NOT_FOUND, 7: LIQUID_LEVEL_CHANGED, 8: LIQUID_STATE_CHANGED
                      if (eventCode == 5) { // DRINK_TEMPERATURE_CHANGED
              _readCurrentTemp();
            } else if (eventCode == 4) { // TARGET_TEMPERATURE_CHANGED
              _readTargetTemp();
            } else if (eventCode == 7) { // LIQUID_LEVEL_CHANGED
              _readLiquidLevel();
            } else if (eventCode == 8) { // LIQUID_STATE_CHANGED
              _readLiquidState();
              // If cup becomes empty, turn off heat by setting target temp to 0
              if (isEmpty && _targetTemp != null && _targetTemp! > 0) {
                debugPrint("EmberService: Cup is empty, turning off heat");
                setTargetTemp(0);
              }
            } else if (eventCode == 1) { // BATTERY_CHANGED
              _readBatteryLevel();
            } else if (eventCode == 2) { // CHARGER_CONNECTED
              _isCharging = true;
              _readBatteryLevel();
            } else if (eventCode == 3) { // CHARGER_DISCONNECTED
              _isCharging = false;
              _readBatteryLevel();
            }
           // Add more event handlers as needed
         }
      });
      
      debugPrint("EmberService: Success subscribing to ${characteristic.uuid}");
    } catch (e) {
      debugPrint("EmberService: Failed to subscribe to ${characteristic.uuid}: $e");
      // Don't rethrow - we want to continue even if notifications fail
    }
  }
  
  Future<void> _readCurrentTemp() async {
    if (_currentTempChar == null) return;
    try {
      List<int> value = await _currentTempChar!.read();
      _currentTemp = _parseTemp(value);
      debugPrint("EmberService: Current temp: $_currentTemp°C");
      NotificationService().showTemperatureNotification(
        _currentTemp ?? 0, 
        isHeating: isHeating,
        isPerfect: isPerfect,
        isOff: (_targetTemp ?? 0) <= 1.0,
        batteryPercent: batteryLevel,
      );
      notifyListeners();
    } catch (e) {
      debugPrint("EmberService: Error reading current temp: $e");
    }
  }
  
  Future<void> _readTargetTemp() async {
    if (_targetTempChar == null) return;
    try {
      List<int> value = await _targetTempChar!.read();
      _targetTemp = _parseTemp(value);
      debugPrint("EmberService: Target temp: $_targetTemp°C");
      notifyListeners();
    } catch (e) {
      debugPrint("EmberService: Error reading target temp: $e");
    }
  }

  Future<void> _readLiquidLevel() async {
    if (_liquidLevelChar == null) return;
    try {
      List<int> value = await _liquidLevelChar!.read();
      if (value.isNotEmpty) {
        _liquidLevel = value[0] | (value.length > 1 ? value[1] << 8 : 0);
        debugPrint("EmberService: Liquid level: $_liquidLevel");
        notifyListeners();
      }
    } catch (e) {
      debugPrint("EmberService: Error reading liquid level: $e");
    }
  }

  Future<void> _readLiquidState() async {
    if (_liquidStateChar == null) return;
    try {
      List<int> value = await _liquidStateChar!.read();
      if (value.isNotEmpty) {
        _liquidState = value[0];
        String stateName = _getLiquidStateName(_liquidState!);
        debugPrint("EmberService: Liquid state: $_liquidState ($stateName)");
        if (_currentTemp != null) {
             NotificationService().showTemperatureNotification(
               _currentTemp!, 
               isHeating: isHeating,
               isPerfect: isPerfect,
               isOff: (_targetTemp ?? 0) <= 1.0,
               batteryPercent: batteryLevel,
             );
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint("EmberService: Error reading liquid state: $e");
    }
  }

  Future<void> _readBatteryLevel() async {
    if (_batteryChar == null) return;
    try {
      List<int> value = await _batteryChar!.read();
      if (value.isNotEmpty) {
        _batteryLevel = value[0];
        if (value.length > 1) {
          _isCharging = (value[1] == 1);
        }
        debugPrint("EmberService: Battery level: $_batteryLevel%, Charging: $_isCharging");
        if (_currentTemp != null) {
          NotificationService().showTemperatureNotification(
            _currentTemp!, 
            isHeating: isHeating,
            isPerfect: isPerfect,
            isOff: (_targetTemp ?? 0) <= 1.0,
            batteryPercent: _batteryLevel,
          );
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint("EmberService: Error reading battery level: $e");
    }
  }

  String _getLiquidStateName(int state) {
    const stateNames = {
      0: 'Standby',
      1: 'Empty',
      2: 'Filling',
      3: 'Cold (No control)',
      4: 'Cooling',
      5: 'Heating',
      6: 'Perfect',
      7: 'Warm (No control)',
    };
    return stateNames[state] ?? 'Unknown';
  }

  Future<void> setTargetTemp(double temp) async {
    if (_targetTempChar == null) return;
    
    // Safety check: Don't allow temperature updates if cup is empty
    if (isEmpty) {
      debugPrint("EmberService: Cannot set temperature - cup is empty!");
      // Force target temp to 0 (off) when empty
      temp = 0;
    }
    
    try {
      int raw = (temp / 0.01).round();
      List<int> bytes = [raw & 0xFF, (raw >> 8) & 0xFF];
      await _targetTempChar!.write(bytes);
      _targetTemp = temp; // Optimistic update
      
      
      // Only save non-zero temperatures so we can restore the last used temp when toggling on
      if (temp > 0) {
        _lastValidTargetTemp = temp;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('ember_target_temp', temp);
      }
      
      notifyListeners();
      
      // Update notification immediately to reflect potential Off state or Heating state change
      if (_currentTemp != null) {
        NotificationService().showTemperatureNotification(
          _currentTemp!, 
          isHeating: isHeating,
          isPerfect: isPerfect,
          isOff: (_targetTemp ?? 0) <= 1.0,
          batteryPercent: batteryLevel,
        );
      }
    } catch (e) {
      debugPrint("Error setting target temp: $e");
    }
  }

  Future<void> toggleHeating() async {
    if ((_targetTemp ?? 0) > 1.0) { // Check > 1.0 to account for potential 0.0 or near-zero readings
       // Turn off
       await setTargetTemp(0);
    } else {
       // Turn on
       final prefs = await SharedPreferences.getInstance();
       final savedTemp = prefs.getDouble('ember_target_temp');
       // Default to 57.0C (approx 135F) if no saved temp found
       await setTargetTemp(savedTemp ?? 57.0);
    }
  }


  
  Future<void> setLedColor(Color color) async {
    if (_ledChar == null) return;
    try {
      List<int> bytes = [
        (color.r * 255).round(),
        (color.g * 255).round(),
        (color.b * 255).round(),
        (color.a * 255).round()
      ];
      await _ledChar!.write(bytes);
    } catch (e) {
      debugPrint("Error setting LED color: $e");
    }
  }

  void disconnect() {
    _connectedDevice?.disconnect();
    _connectedDevice = null;
    _currentTempChar = null;
    _targetTempChar = null;
    _ledChar = null;
    _liquidLevelChar = null;
    _liquidStateChar = null;
    _batteryChar = null;
    _pushEventChar = null;
    _connectionSubscription?.cancel();
    NotificationService().cancel();
    notifyListeners();
  }

  double _parseTemp(List<int> value) {
    if (value.length < 2) return 0.0;
    // Assuming 16-bit little endian
    int raw = value[0] | (value[1] << 8);
    // Python code: float(int.from_bytes(data, 'little')) * 0.01
    return raw * 0.01;
  }
}
