import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    
    await _requestPermissions();
  }
  
  Future<void> _requestPermissions() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  Future<void> showTemperatureNotification(double tempCelsius, {bool isHeating = false, bool isOff = false, bool isPerfect = false, int? batteryPercent}) async {
    final prefs = await SharedPreferences.getInstance();
    final unitString = prefs.getString(SettingsService.tempUnitKey);
    final isFahrenheit = unitString != 'celsius'; // Default to Fahrenheit if null or anything else

    double displayTemp = tempCelsius;
    String unitSymbol = '°C';

    if (isFahrenheit) {
      displayTemp = (tempCelsius * 9 / 5) + 32;
      unitSymbol = '°F';
    }

    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'ember_temperature_updates', // Changed channel ID to apply new importance settings
      'Ember Temperature',
      channelDescription: 'Shows the current temperature of the Ember Mug',
      importance: Importance.high, // Increased importance
      priority: Priority.high, // Increased priority
      showWhen: false,
      onlyAlertOnce: true, // Crucial: alerts only once, then updates silently
      playSound: false, // We still probably don't want a sound for every update, but High helps visibility
      ongoing: true,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    String tempString = isFahrenheit 
        ? displayTemp.toStringAsFixed(0) 
        : displayTemp.toStringAsFixed(1);
        
    String statusSuffix = "";
    if (isOff) {
      statusSuffix = " (Off)";
    } else if (isPerfect) {
      statusSuffix = " (Perfect)";
    } else if (isHeating) {
      statusSuffix = " (Heating)";
    }

    String title = 'Ember Mug';
    if (batteryPercent != null) {
      title = 'Ember Mug ($batteryPercent%)';
    }

    await flutterLocalNotificationsPlugin.show(
      88, // Constant ID
      '$tempString$unitSymbol$statusSuffix',
      title,
      notificationDetails,
    );
  }
  
  Future<void> showTimerFinishedNotification() async {
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'ember_timer_updates',
        'Steep Timer',
        channelDescription: 'Notifications for the steep timer',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      );

      const NotificationDetails notificationDetails =
          NotificationDetails(android: androidNotificationDetails);

      await flutterLocalNotificationsPlugin.show(
        89,
        'Timer Finished',
        'Your steep timer is done!',
        notificationDetails,
      );
  }

  Future<void> cancel() async {
      await flutterLocalNotificationsPlugin.cancel(88);
      await flutterLocalNotificationsPlugin.cancel(89);
  }
}
