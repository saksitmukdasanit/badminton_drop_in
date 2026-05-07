import 'package:badminton/component/notification_provider.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:badminton/navigator_key.dart'; // Import GlobalKey
import 'package:provider/provider.dart';
import 'package:badminton/shared/user_role.dart';
import 'package:badminton/shared/booking_details_mapper.dart';

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
  void _handleMessage(RemoteMessage message) async {
    final referenceId = message.data['referenceId'];
    if (referenceId != null && referenceId.isNotEmpty) {
      // อ่าน role ก่อนข้าม async gap
      final ctx0 = navigatorKey.currentContext;
      if (ctx0 == null || !ctx0.mounted) return;
      final role = Provider.of<UserRoleProvider>(ctx0, listen: false).currentRole;
      final type = message.data['type']?.toString();

      try {
        if (role == Role.organizer) {
          // Organizer: ใช้ logic แบบเดียวกับ terminated handler (ดู main.dart) เพื่อลดการเด้งผิดหน้า
          final response = await ApiProvider().get('/GameSessions/$referenceId');
          final ctx = navigatorKey.currentContext;
          if (ctx == null || !ctx.mounted) return;

          if (response is Map &&
              response['status'] == 200 &&
              response['data'] != null) {
            final int status = (response['data']['status'] as num?)?.toInt() ?? 1;
            if (status == 1) {
              ctx.go('/manage');
            } else if (status == 2) {
              ctx.push('/manage-game/$referenceId');
            } else {
              ctx.push('/history-organizer-payment',
                  extra: int.parse(referenceId));
            }
          } else {
            ctx.push('/manage-game/$referenceId');
          }
          return;
        }

        // Player: ถ้าเป็น noti "ก๊วนใหม่จากผู้จัดที่ติดตาม" หรือยังไม่ได้ join → ควรไปหน้า booking-confirm (รายละเอียด/จอง)
        final res = await ApiProvider().get('/player/gamesessions/$referenceId');
        final ctx = navigatorKey.currentContext;
        if (ctx == null || !ctx.mounted) return;

        if (res is Map && res['status'] == 200 && res['data'] is Map) {
          final data = Map<String, dynamic>.from(res['data'] as Map);
          final details = bookingDetailsFromUpcomingCardMap(data);
          final userStatus = (data['userStatus'] ?? '').toString();

          final bool shouldOpenBooking =
              type == 'NEW_SESSION_FROM_FOLLOWED_ORGANIZER' ||
              userStatus.isEmpty ||
              userStatus == 'NotJoined';

          if (shouldOpenBooking) {
            ctx.push('/booking-confirm', extra: details);
          } else {
            ctx.push('/game-player/$referenceId');
          }
        } else {
          // fallback เดิม
          ctx.push('/game-player/$referenceId');
        }
      } catch (_) {
        // fallback เดิม
        final ctx = navigatorKey.currentContext;
        if (ctx == null || !ctx.mounted) return;
        if (role == Role.organizer) {
          ctx.push('/manage-game/$referenceId');
        } else {
          ctx.push('/game-player/$referenceId');
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
      
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        Provider.of<NotificationProvider>(context, listen: false).increment();
      }
    });

    // 5. --- NEW: จัดการเมื่อกด Noti ตอนแอปเปิดอยู่ (Foreground/Background) ---
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    // 6. --- NEW: จัดการเมื่อกด Noti ตอนแอปปิดสนิท (Terminated) ---
    // (ย้ายไปจัดการใน main.dart เพื่อให้แน่ใจว่า UI และ GoRouter สร้างเสร็จแล้ว)
    
    // 7. อัปเดต FCM Token ไปยัง Backend ทุกครั้งที่เริ่มแอป
    await updateTokenToServer();
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
      // บน iOS/macOS ต้องรอให้ได้รับ APNS Token ก่อนจึงจะขอ FCM Token ได้
      if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS)) {
        String? apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken == null) {
          // หากยังไม่ได้ ให้รอสักพัก (เผื่อ OS กำลังลงทะเบียน) แล้วลองดึงใหม่
          await Future.delayed(const Duration(seconds: 3));
          apnsToken = await _firebaseMessaging.getAPNSToken();
          if (apnsToken == null) {
            debugPrint("APNS token is not ready. Skipping FCM token update.");
            return;
          }
        }
      }

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