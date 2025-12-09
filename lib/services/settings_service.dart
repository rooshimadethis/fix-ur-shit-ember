import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TemperatureUnit {
  celsius,
  fahrenheit,
}

class SettingsService extends ChangeNotifier {
  static const String _tempUnitKey = 'temperature_unit';
  
  TemperatureUnit _temperatureUnit = TemperatureUnit.fahrenheit; // Default to Fahrenheit
  TemperatureUnit get temperatureUnit => _temperatureUnit;
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  SettingsService() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final unitString = prefs.getString(_tempUnitKey);
    
    if (unitString != null) {
      _temperatureUnit = unitString == 'celsius' 
          ? TemperatureUnit.celsius 
          : TemperatureUnit.fahrenheit;
    }
    
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setTemperatureUnit(TemperatureUnit unit) async {
    _temperatureUnit = unit;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tempUnitKey, unit == TemperatureUnit.celsius ? 'celsius' : 'fahrenheit');
  }

  // Convert Celsius to Fahrenheit
  double celsiusToFahrenheit(double celsius) {
    return (celsius * 9 / 5) + 32;
  }

  // Convert Fahrenheit to Celsius
  double fahrenheitToCelsius(double fahrenheit) {
    return (fahrenheit - 32) * 5 / 9;
  }

  // Display temperature in the user's preferred unit
  double displayTemp(double celsius) {
    return _temperatureUnit == TemperatureUnit.fahrenheit 
        ? celsiusToFahrenheit(celsius) 
        : celsius;
  }

  // Convert display temperature back to Celsius for the device
  double toDeviceTemp(double displayTemp) {
    return _temperatureUnit == TemperatureUnit.fahrenheit 
        ? fahrenheitToCelsius(displayTemp) 
        : displayTemp;
  }

  String get unitSymbol => _temperatureUnit == TemperatureUnit.celsius ? '°C' : '°F';
  
  // Get min/max temps in the current unit
  double get minTemp => _temperatureUnit == TemperatureUnit.celsius ? 50.0 : 122.0;
  double get maxTemp => _temperatureUnit == TemperatureUnit.celsius ? 65.0 : 149.0;
}
