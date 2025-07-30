import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:io';

import 'api_service.dart';
import 'storage_service.dart';

enum NotificationPriority {
  min,
  low,
  defaultPriority,
  high,
  max,
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  static bool _initialized = false;

  // Initialize notification service
  static Future<void> init() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;

    if (kDebugMode) {
      print('✅ Notification service initialized');
    }

    await initPushNotifications();
  }

  // Initialize Push Notifications
  static Future<void> initPushNotifications() async {
    await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    final String? fcmToken = await _firebaseMessaging.getToken();
    if (kDebugMode) {
      print('📱 FCM Token: $fcmToken');
    }

    if (fcmToken != null) {
      await _sendFcmTokenToBackend(fcmToken);
    }

    _handleIncomingNotifications();
  }

  // Send FCM token to backend
  static Future<void> _sendFcmTokenToBackend(String token) async {
    try {
      // User must be logged in to send a token
      final userToken = await StorageService.getToken();
      if (userToken == null || userToken.isEmpty) {
        if (kDebugMode) {
          print('🔔 User not authenticated. Skipping FCM token send.');
        }
        return;
      }

      if (kDebugMode) {
        print('🚀 Sending FCM token to backend...');
      }

      final api = ApiService();
      final response = await api.put(
        '/users/fcm-token',
        data: {'fcmToken': token},
      );

      if (response.isSuccess) {
        if (kDebugMode) {
          print('✅ FCM token successfully sent to backend.');
        }
      } else {
        if (kDebugMode) {
          print(
              '❌ Failed to send FCM token. Message: ${response.message}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Exception when sending FCM token: $e');
      }
    }
  }

  static void _handleIncomingNotifications() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('📱 Got a message whilst in the foreground!');
        print('Message data: ${message.data}');
      }

      if (message.notification != null) {
        if (kDebugMode) {
          print('Message also contained a notification: ${message.notification}');
        }
        showNotification(
          id: message.hashCode,
          title: message.notification!.title ?? 'Nouvelle Notification',
          body: message.notification!.body ?? '',
          payload: message.data['payload'] as String?,
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('📱 Notification caused app to open from background: ${message.data}');
      }
      // TODO: Handle navigation based on payload
    });

    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        if (kDebugMode) {
          print('📱 Notification caused app to open from terminated state: ${message.data}');
        }
        // TODO: Handle navigation based on payload
      }
    });
  }

  static void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      print('📱 Notification tapped: ${response.payload}');
    }
    // TODO: Handle navigation based on payload
  }

  static Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final bool? granted =
            await androidImplementation.requestNotificationsPermission();
        return granted ?? false;
      }
    } else if (Platform.isIOS) {
      final bool? result = await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    }

    return true;
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    NotificationPriority priority = NotificationPriority.defaultPriority,
  }) async {
    if (!_initialized) await init();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'doctors_app_channel',
      'Doctors App Notifications',
      channelDescription: 'Notifications for appointment reminders and updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_initialized) await init();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'doctors_app_scheduled',
      'Scheduled Notifications',
      channelDescription: 'Scheduled notifications for appointments',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tzDateTime,
      platformDetails,
      payload: payload,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  static Future<List<PendingNotificationRequest>>
      getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  static Future<void> scheduleAppointmentReminder({
    required String appointmentId,
    required String doctorName,
    required DateTime appointmentDate,
    required String clinicName,
  }) async {
    final reminderDate = appointmentDate.subtract(const Duration(hours: 24));

    if (reminderDate.isAfter(DateTime.now())) {
      await scheduleNotification(
        id: appointmentId.hashCode,
        title: 'Rappel de rendez-vous',
        body:
            'Vous avez un rendez-vous avec Dr $doctorName demain à ${_formatTime(appointmentDate)} - $clinicName',
        scheduledDate: reminderDate,
        payload: 'appointment:$appointmentId',
      );
    }
  }

  static Future<void> showAppointmentConfirmation({
    required String doctorName,
    required DateTime appointmentDate,
    required String clinicName,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch,
      title: 'Rendez-vous confirmé',
      body:
          'Votre rendez-vous avec Dr $doctorName le ${_formatDate(appointmentDate)} à ${_formatTime(appointmentDate)} est confirmé - $clinicName',
      priority: NotificationPriority.high,
    );
  }

  static Future<void> showAppointmentCancellation({
    required String doctorName,
    required DateTime appointmentDate,
    String? reason,
  }) async {
    String body =
        'Votre rendez-vous avec Dr $doctorName le ${_formatDate(appointmentDate)} à ${_formatTime(appointmentDate)} a été annulé';

    if (reason != null && reason.isNotEmpty) {
      body += '. Motif: $reason';
    }

    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch,
      title: 'Rendez-vous annulé',
      body: body,
      priority: NotificationPriority.high,
    );
  }

  static Future<void> showNewMessage({
    required String senderName,
    required String message,
    required String conversationId,
  }) async {
    await showNotification(
      id: conversationId.hashCode,
      title: 'Nouveau message de $senderName',
      body: message,
      payload: 'message:$conversationId',
    );
  }

  static Future<void> showDoctorVerificationUpdate({
    required bool approved,
    String? notes,
  }) async {
    final title =
        approved ? 'Profil médecin approuvé' : 'Profil médecin rejeté';
    String body = approved
        ? 'Félicitations! Votre profil médecin a été approuvé. Vous pouvez maintenant recevoir des rendez-vous.'
        : 'Votre demande de profil médecin a été rejetée.';

    if (notes != null && notes.isNotEmpty) {
      body += ' Note: $notes';
    }

    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch,
      title: title,
      body: body,
      priority: NotificationPriority.high,
    );
  }

  static Future<void> showGeneralNotification({
    required String title,
    required String message,
    String? payload,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch,
      title: title,
      body: message,
      payload: payload,
    );
  }

  static String _formatDate(DateTime date) {
    const months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // Format time for display
  static String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
