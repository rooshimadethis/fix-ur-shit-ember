import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

enum TemperatureUnit { celsius, fahrenheit }

class SettingsService extends ChangeNotifier {
  static const String tempUnitKey = 'temperature_unit';
  static const String showTimerKey = 'show_steep_timer';

  static const String timerDurationKey = 'steep_timer_duration';
  static const String timerTargetTimeKey = 'steep_timer_target_time';
  static const String ledColorKey = 'led_color';
  static const String enableGreenLoopKey = 'enable_green_loop';
  static const String showLiquidAnimationKey = 'show_liquid_animation';
  static const String showDebugControlsKey = 'show_debug_controls';
  static const String presetsKey = 'temperature_presets';
  static const String presetCountKey = 'preset_count';

  static const List<Map<String, dynamic>> defaultPresets = [
    {'name': 'Coffee', 'icon': '☕', 'temp': 57.0},
    {'name': 'Tea', 'icon': '🍵', 'temp': 60.0},
    {'name': 'Hot Choc', 'icon': '🍫', 'temp': 55.0},
    {'name': 'Latte', 'icon': '🥛', 'temp': 52.0},
  ];

  List<Map<String, dynamic>> _presets = List.from(defaultPresets);
  List<Map<String, dynamic>> get presets => _presets;

  int _presetCount = 2;
  int get presetCount => _presetCount;

  bool _showSteepTimer = true;
  bool get showSteepTimer => _showSteepTimer;

  int _steepTimerDuration = 300; // Default 5 minutes
  int get steepTimerDuration => _steepTimerDuration;

  DateTime? _steepTimerTargetTime;
  DateTime? get steepTimerTargetTime => _steepTimerTargetTime;

  TemperatureUnit _temperatureUnit =
      TemperatureUnit.fahrenheit; // Default to Fahrenheit
  TemperatureUnit get temperatureUnit => _temperatureUnit;

  Color _ledColor = const Color(0xFFFF0000); // Default to Red
  Color get ledColor => _ledColor;

  bool _enableGreenLoop = true;
  bool get enableGreenLoop => _enableGreenLoop;

  bool _showLiquidAnimation = true;
  bool get showLiquidAnimation => _showLiquidAnimation;

  bool _showDebugControls = true;
  bool get showDebugControls => _showDebugControls;

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

    _presetCount = prefs.getInt(presetCountKey) ?? 2;
    final presetsString = prefs.getString(presetsKey);
    if (presetsString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(presetsString);
        _presets = decoded.cast<Map<String, dynamic>>();
      } catch (e) {
        debugPrint("Error loading presets: $e");
        _presets = List.from(defaultPresets);
      }
    } else {
      _presets = List.from(defaultPresets);
    }

    final int? targetTimeMillis = prefs.getInt(timerTargetTimeKey);
    if (targetTimeMillis != null) {
      _steepTimerTargetTime = DateTime.fromMillisecondsSinceEpoch(
        targetTimeMillis,
      );
    }

    _enableGreenLoop = prefs.getBool(enableGreenLoopKey) ?? true;
    _showLiquidAnimation = prefs.getBool(showLiquidAnimationKey) ?? true;
    _showDebugControls = prefs.getBool(showDebugControlsKey) ?? true;

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

  Future<void> setSteepTimerTargetTime(DateTime? targetTime) async {
    _steepTimerTargetTime = targetTime;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (targetTime != null) {
      await prefs.setInt(timerTargetTimeKey, targetTime.millisecondsSinceEpoch);
    } else {
      await prefs.remove(timerTargetTimeKey);
    }
  }

  Future<void> setLedColor(Color color) async {
    _ledColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(ledColorKey, color.toARGB32());
  }

  Future<void> setEnableGreenLoop(bool value) async {
    _enableGreenLoop = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enableGreenLoopKey, value);
  }

  Future<void> setShowLiquidAnimation(bool value) async {
    _showLiquidAnimation = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(showLiquidAnimationKey, value);
  }

  Future<void> setShowDebugControls(bool value) async {
    _showDebugControls = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(showDebugControlsKey, value);
  }

  Future<void> setPresetCount(int value) async {
    _presetCount = value.clamp(1, 4);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(presetCountKey, _presetCount);
  }

  Future<void> updatePreset(
    int index,
    String name,
    String icon,
    double tempCelsius,
  ) async {
    if (index >= 0 && index < _presets.length) {
      _presets[index] = {'name': name, 'icon': icon, 'temp': tempCelsius};
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(presetsKey, jsonEncode(_presets));
    }
  }

  Future<void> setTemperatureUnit(TemperatureUnit unit) async {
    _temperatureUnit = unit;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      tempUnitKey,
      unit == TemperatureUnit.celsius ? 'celsius' : 'fahrenheit',
    );
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

  String get unitSymbol =>
      _temperatureUnit == TemperatureUnit.celsius ? '°C' : '°F';

  // Get min/max temps in the current unit
  double get minTemp =>
      _temperatureUnit == TemperatureUnit.celsius ? 50.0 : 122.0;
  double get maxTemp =>
      _temperatureUnit == TemperatureUnit.celsius ? 65.0 : 149.0;
}
