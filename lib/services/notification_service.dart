import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_service.dart';

import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  // Notification ID constants
  static const int temperatureNotificationId = 88;
  static const int timerNotificationId = 89;
  static const int drinkReadyNotificationId = 90;

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

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          macOS: initializationSettingsDarwin,
        );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    tz.initializeTimeZones();
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
      debugPrint(
        'NotificationService: Timezone set to ${timeZoneInfo.identifier}',
      );
    } catch (e) {
      debugPrint('NotificationService: Error setting local timezone: $e');
      // Fallback to UTC if timezone detection fails
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final notificationStatus = await Permission.notification.status;
    if (notificationStatus.isDenied) {
      await Permission.notification.request();
    }

    // Request exact alarm permission for Android 12+
    final alarmStatus = await Permission.scheduleExactAlarm.status;
    if (alarmStatus.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  Future<void> showTemperatureNotification(
    double tempCelsius, {
    bool isHeating = false,
    bool isOff = false,
    bool isPerfect = false,
    int? batteryPercent,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final unitString = prefs.getString(SettingsService.tempUnitKey);
    final isFahrenheit =
        unitString !=
        'celsius'; // Default to Fahrenheit if null or anything else

    double displayTemp = tempCelsius;
    String unitSymbol = '°C';

    if (isFahrenheit) {
      displayTemp = (tempCelsius * 9 / 5) + 32;
      unitSymbol = '°F';
    }

    const AndroidNotificationDetails
    androidNotificationDetails = AndroidNotificationDetails(
      'ember_temperature_updates', // Changed channel ID to apply new importance settings
      'Ember Temperature',
      channelDescription: 'Shows the current temperature of the Ember Mug',
      importance: Importance.high, // Increased importance
      priority: Priority.high, // Increased priority
      showWhen: false,
      onlyAlertOnce: true, // Crucial: alerts only once, then updates silently
      playSound:
          false, // We still probably don't want a sound for every update, but High helps visibility
      ongoing: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

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
      temperatureNotificationId,
      '$tempString$unitSymbol$statusSuffix',
      title,
      notificationDetails,
    );
  }

  Future<void> showTimerFinishedNotification() async {
    await _showTimerNotification('Your steep timer is done!');
  }

  Future<void> scheduleTimerFinishedNotification(Duration duration) async {
    final vibrationPattern = Int64List.fromList([0, 1000, 500, 1000]);
    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'ember_timer_v3', // Consistent channel ID
          'Steep Timer',
          channelDescription: 'Notifications for the steep timer',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: vibrationPattern,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          groupKey: 'com.fix_ur_shit_ember.TIMER',
          visibility: NotificationVisibility.public,
        );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    final scheduledTime = tz.TZDateTime.now(tz.local).add(duration);

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        timerNotificationId,
        'Timer Finished!',
        'Your steep timer is done!',
        scheduledTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Error scheduling exact notification: $e');
      // Fallback to inexact if permission missing
      await flutterLocalNotificationsPlugin.zonedSchedule(
        timerNotificationId,
        'Timer Finished',
        'Your steep timer is done! (Inexact)',
        scheduledTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> showOngoingTimerNotification(DateTime targetTime) async {
    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'ember_timer_ongoing',
          'Ongoing Timer',
          channelDescription: 'Shows the remaining time for the steep timer',
          importance:
              Importance.low, // Low importance so it doesn't pop up/make noise
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          showWhen: true,
          when: targetTime.millisecondsSinceEpoch,
          usesChronometer: true,
          chronometerCountDown: true,
          category: AndroidNotificationCategory.progress,
          groupKey: 'com.fix_ur_shit_ember.TIMER',
          groupAlertBehavior: GroupAlertBehavior.children,
        );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      timerNotificationId +
          100, // Different ID to avoid clashing with final notification
      'Steep Timer Running',
      null,
      notificationDetails,
    );
  }

  Future<void> cancelTimerNotifications() async {
    await flutterLocalNotificationsPlugin.cancel(timerNotificationId);
    await flutterLocalNotificationsPlugin.cancel(timerNotificationId + 100);
  }

  Future<void> cancelTimerNotification() async {
    await cancelTimerNotifications();
  }

  Future<void> _showTimerNotification(String body) async {
    final vibrationPattern = Int64List.fromList([0, 1000, 500, 1000]);
    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'ember_timer_v3', // Use same channel as scheduled
          'Steep Timer',
          channelDescription: 'Notifications for the steep timer',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: vibrationPattern,
          category: AndroidNotificationCategory.alarm,
        );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      timerNotificationId,
      'Timer Finished',
      body,
      notificationDetails,
    );
  }

  Future<void> showDrinkReadyNotification(double tempCelsius) async {
    final prefs = await SharedPreferences.getInstance();
    final unitString = prefs.getString(SettingsService.tempUnitKey);
    final isFahrenheit = unitString != 'celsius'; // Default to Fahrenheit

    double displayTemp = tempCelsius;
    String unitSymbol = '°C';

    if (isFahrenheit) {
      displayTemp = (tempCelsius * 9 / 5) + 32;
      unitSymbol = '°F';
    }

    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'ember_drink_ready',
          'Drink Ready',
          channelDescription:
              'Notifications when your drink reaches strict temperature',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      drinkReadyNotificationId,
      'Drink Ready!',
      'Your beverage has reached ${displayTemp.toStringAsFixed(0)}$unitSymbol',
      notificationDetails,
    );
  }

  Future<void> cancel() async {
    await flutterLocalNotificationsPlugin.cancel(temperatureNotificationId);
    await cancelTimerNotifications();
  }
}
