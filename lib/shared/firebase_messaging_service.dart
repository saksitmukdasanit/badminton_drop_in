import 'package:badminton/shared/api_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:badminton/navigator_key.dart'; // Import GlobalKey
import 'package:provider/provider.dart';
import 'package:badminton/shared/user_role.dart';

// Top-level function ต้องอยู่นอก Class เพื่อรับ Notification ตอนแอปปิดอยู่ (Background/Terminated)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

class FirebaseMessagingService {
  static final FirebaseMessagingService _instance = FirebaseMessagingService._internal();
  factory FirebaseMessagingService() => _instance;
  FirebaseMessagingService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // --- NEW: Function to handle navigation ---
  void _handleMessage(RemoteMessage message) {
    final referenceId = message.data['referenceId'];
    if (referenceId != null && referenceId.isNotEmpty) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        final role = Provider.of<UserRoleProvider>(context, listen: false).currentRole;
        if (role == Role.organizer) {
          context.push('/manage-game/$referenceId');
        } else {
          context.push('/game-player/$referenceId');
        }
      }
    }
  }

  Future<void> init() async {
    // 1. ขออนุญาตรับการแจ้งเตือน (จำเป็นมากสำหรับ iOS)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    }

    // 2. ตั้งค่าทำงานเบื้องหลัง (Background)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. ตั้งค่า Local Notifications สำหรับแสดง Noti เด้งตอนแอปเปิดอยู่ (Foreground)
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
      // --- NEW: Callback เมื่อกด Noti ตอนแอปเปิดอยู่ (Foreground) ---
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // เราจะใช้ onMessageOpenedApp จัดการแทนเพื่อรวม Logic ไว้ที่เดียว
      },
    );

    // 4. จัดการเมื่อมี Noti เข้ามาตอนเปิดแอปอยู่ (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // 5. --- NEW: จัดการเมื่อกด Noti ตอนแอปเปิดอยู่ (Foreground/Background) ---
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    // 6. --- NEW: จัดการเมื่อกด Noti ตอนแอปปิดสนิท (Terminated) ---
    // (ย้ายไปจัดการใน main.dart เพื่อให้แน่ใจว่า UI และ GoRouter สร้างเสร็จแล้ว)
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null && !kIsWeb) {
      await _localNotificationsPlugin.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel', // id
            'High Importance Notifications', // title
            channelDescription: 'This channel is used for important notifications.',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
        ),
        payload: message.data['referenceId'], // ส่ง referenceId ไปกับ payload
      );
    }
  }

  // 5. ฟังก์ชันสำหรับดึง Token แล้วส่งให้ Backend
  Future<void> updateTokenToServer() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        debugPrint("FCM Token: $token");
        // ส่ง Token ไปบันทึกที่ Backend
        await ApiProvider().post('/Notifications/fcm-token', data: {'token': token});
      }
    } catch (e) {
      debugPrint("Failed to update FCM token: $e");
    }
  }
}