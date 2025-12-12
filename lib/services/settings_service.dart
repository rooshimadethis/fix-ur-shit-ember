import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TemperatureUnit {
  celsius,
  fahrenheit,
}

class SettingsService extends ChangeNotifier {
  static const String tempUnitKey = 'temperature_unit';
  static const String showTimerKey = 'show_steep_timer';

  static const String timerDurationKey = 'steep_timer_duration';
  static const String ledColorKey = 'led_color';

  bool _showSteepTimer = true;
  bool get showSteepTimer => _showSteepTimer;

  int _steepTimerDuration = 300; // Default 5 minutes
  int get steepTimerDuration => _steepTimerDuration;

  TemperatureUnit _temperatureUnit = TemperatureUnit.fahrenheit; // Default to Fahrenheit
  TemperatureUnit get temperatureUnit => _temperatureUnit;

  Color _ledColor = const Color(0xFFFF0000); // Default to Red
  Color get ledColor => _ledColor;
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  SettingsService() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final unitString = prefs.getString(tempUnitKey);
    
    if (unitString != null) {
      _temperatureUnit = unitString == 'celsius' 
          ? TemperatureUnit.celsius 
          : TemperatureUnit.fahrenheit;
    }

    _showSteepTimer = prefs.getBool(showTimerKey) ?? true;
    _steepTimerDuration = prefs.getInt(timerDurationKey) ?? 300;
    

    
    final int? colorValue = prefs.getInt(ledColorKey);
    if (colorValue != null) {
      _ledColor = Color(colorValue);
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setShowSteepTimer(bool value) async {
    _showSteepTimer = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(showTimerKey, value);
  }

  Future<void> setSteepTimerDuration(int seconds) async {
    _steepTimerDuration = seconds;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(timerDurationKey, seconds);
  }

  Future<void> setLedColor(Color color) async {
    _ledColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(ledColorKey, color.toARGB32());
  }

  Future<void> setTemperatureUnit(TemperatureUnit unit) async {
    _temperatureUnit = unit;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tempUnitKey, unit == TemperatureUnit.celsius ? 'celsius' : 'fahrenheit');
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
