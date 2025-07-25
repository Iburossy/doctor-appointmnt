import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:io';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  static bool _initialized = false;
  
  // Initialize notification service
  static Future<void> init() async {
    if (_initialized) return;
    
    // Android initialization settings
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS initialization settings
    const DarwinInitializationSettings iosSettings = 
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    // Combined initialization settings
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    // Initialize
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    _initialized = true;
    
    if (kDebugMode) {
      print('✅ Notification service initialized');
    }
  }
  
  // Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      print('📱 Notification tapped: ${response.payload}');
    }
    
    // TODO: Handle navigation based on payload
    // This will be implemented when we add navigation
  }
  
  // Request permissions (mainly for iOS)
  static Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        final bool? granted = await androidImplementation
            .requestNotificationsPermission();
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
  
  // Show immediate notification
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
  
  // Schedule notification
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
  
  // Cancel notification
  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }
  
  // Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
  
  // Get pending notifications
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }
  
  // Appointment reminder notification
  static Future<void> scheduleAppointmentReminder({
    required String appointmentId,
    required String doctorName,
    required DateTime appointmentDate,
    required String clinicName,
  }) async {
    final reminderDate = appointmentDate.subtract(const Duration(hours: 24));
    
    // Only schedule if reminder is in the future
    if (reminderDate.isAfter(DateTime.now())) {
      await scheduleNotification(
        id: appointmentId.hashCode,
        title: 'Rappel de rendez-vous',
        body: 'Vous avez un rendez-vous avec Dr $doctorName demain à ${_formatTime(appointmentDate)} - $clinicName',
        scheduledDate: reminderDate,
        payload: 'appointment:$appointmentId',
      );
    }
  }
  
  // Appointment confirmation notification
  static Future<void> showAppointmentConfirmation({
    required String doctorName,
    required DateTime appointmentDate,
    required String clinicName,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch,
      title: 'Rendez-vous confirmé',
      body: 'Votre rendez-vous avec Dr $doctorName le ${_formatDate(appointmentDate)} à ${_formatTime(appointmentDate)} est confirmé - $clinicName',
      priority: NotificationPriority.high,
    );
  }
  
  // Appointment cancellation notification
  static Future<void> showAppointmentCancellation({
    required String doctorName,
    required DateTime appointmentDate,
    String? reason,
  }) async {
    String body = 'Votre rendez-vous avec Dr $doctorName le ${_formatDate(appointmentDate)} à ${_formatTime(appointmentDate)} a été annulé';
    
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
  
  // New message notification
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
  
  // Doctor verification notification
  static Future<void> showDoctorVerificationUpdate({
    required bool approved,
    String? notes,
  }) async {
    final title = approved ? 'Profil médecin approuvé' : 'Profil médecin rejeté';
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
  
  // General app notification
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
  
  // Format date for display
  static String _formatDate(DateTime date) {
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
  
  // Format time for display
  static String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  
  // Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        return await androidImplementation.areNotificationsEnabled() ?? false;
      }
    }
    
    return true; // Assume enabled for iOS and other platforms
  }
}

enum NotificationPriority {
  min,
  low,
  defaultPriority,
  high,
  max,
}
