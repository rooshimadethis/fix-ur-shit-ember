import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../utils/constants.dart';

class EmberService extends ChangeNotifier {
  BluetoothDevice? _connectedDevice;

  BluetoothCharacteristic? _currentTempChar;
  BluetoothCharacteristic? _targetTempChar;
  BluetoothCharacteristic? _ledChar;
  // ignore: unused_field
  BluetoothCharacteristic? _pushEventChar;
  BluetoothCharacteristic? _mugIdChar;
  BluetoothCharacteristic? _dskChar;
  BluetoothCharacteristic? _udskChar;
  BluetoothCharacteristic? _firmwareChar;
  BluetoothCharacteristic? _batteryChar;

  bool _isScanning = false;
  bool get isScanning => _isScanning;
  
  bool get isConnected => _connectedDevice != null;
  
  double? _currentTemp;
  double? get currentTemp => _currentTemp;

  double? _targetTemp;
  double? get targetTemp => _targetTemp;

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
          debugPrint("EmberService: Found device: $name (${result.device.remoteId}) RSSI: ${result.rssi}");
          
          if (name.toLowerCase().contains("ember")) {
             debugPrint("EmberService: FOUND EMBER! Connecting to $name...");
             connect(result.device);
             FlutterBluePlus.stopScan();
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

  void stopScan() {
    FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    _isScanning = false;
    notifyListeners();
  }

  Future<void> connect(BluetoothDevice device) async {
    debugPrint("EmberService: Attempting to connect to ${device.remoteId}...");
    try {
      // mtu: null prevents the auto-request of 512 bytes which causes Error 133 on some Android phones/devices
      await device.connect(autoConnect: false, mtu: null);
      debugPrint("EmberService: Connected!");
      _connectedDevice = device;
      
      // Attempt to pair (match Python implementation)
      try {
        debugPrint("EmberService: Attempting to pair...");
        await device.createBond();
        debugPrint("EmberService: Pairing successful or already paired");
      } catch (e) {
        debugPrint("EmberService: Pairing failed (might be okay if already paired): $e");
      }
      
      // Listen to connection state
      _connectionSubscription = device.connectionState.listen((state) {
        debugPrint("EmberService: Connection state changed to: $state");
        if (state == BluetoothConnectionState.disconnected) {
          disconnect();
        }
      });

      // Discover services immediately - don't wait too long or we'll get link supervision timeout
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
        } else if (charUuidStr == EmberConstants.pushEventCharUuid.toLowerCase()) {
          debugPrint("EmberService: Found Push Event Char (notifications)");
          _pushEventChar = characteristic;
        } else if (charUuidStr == EmberConstants.mugIdCharUuid.toLowerCase()) {
          debugPrint("EmberService: Found Mug ID Char");
          _mugIdChar = characteristic;
        } else if (charUuidStr == EmberConstants.dskCharUuid.toLowerCase()) {
          debugPrint("EmberService: Found DSK Char");
          _dskChar = characteristic;
        } else if (charUuidStr == EmberConstants.udskCharUuid.toLowerCase()) {
          debugPrint("EmberService: Found UDSK Char");
          _udskChar = characteristic;
        } else if (charUuidStr == EmberConstants.firmwareCharUuid.toLowerCase()) {
          debugPrint("EmberService: Found Firmware Char");
          _firmwareChar = characteristic;
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
    
    // Then read current temperature
    if (_currentTempChar != null) {
      await _readCurrentTemp();
    }

    // Read initial attributes (like Python's update_initial)
    await _readInitialAttrs();
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

  Future<void> setTargetTemp(double temp) async {
    if (_targetTempChar == null) return;
    try {
      int raw = (temp / 0.01).round();
      List<int> bytes = [raw & 0xFF, (raw >> 8) & 0xFF];
      await _targetTempChar!.write(bytes);
      _targetTemp = temp; // Optimistic update
      notifyListeners();
    } catch (e) {
      debugPrint("Error setting target temp: $e");
    }
  }

  Future<void> _readInitialAttrs() async {
    // Wait for connection to settle
    debugPrint("EmberService: Waiting for connection to settle...");
    await Future.delayed(const Duration(seconds: 2));
    debugPrint("EmberService: Reading initial attributes...");
    
    // Helper function to read with delay and error handling and retry
    Future<void> safeRead(BluetoothCharacteristic? char, String name) async {
      if (char == null) return;
      int maxRetries = 3;
      for (int i = 0; i < maxRetries; i++) {
        try {
          await Future.delayed(const Duration(milliseconds: 1000)); // 1s delay between reads
          await char.read(); 
          debugPrint("EmberService: Read $name success");
          return; // Success
        } catch (e) {
          debugPrint("EmberService: Failed to read $name (Attempt ${i + 1}/$maxRetries): $e");
          if (i < maxRetries - 1) {
             await Future.delayed(const Duration(milliseconds: 1000)); // Wait before retry
          }
        }
      }
    }

    // Read in sequence with delays
    await safeRead(_mugIdChar, "Mug ID");
    await safeRead(_firmwareChar, "Firmware");
    await safeRead(_batteryChar, "Battery");
    await safeRead(_dskChar, "DSK");
    await safeRead(_udskChar, "UDSK");
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
    _pushEventChar = null;
    _mugIdChar = null;
    _dskChar = null;
    _udskChar = null;
    _firmwareChar = null;
    _batteryChar = null;
    _connectionSubscription?.cancel();
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
