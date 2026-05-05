import 'dart:io';

import 'package:badminton/home_page.dart';
import 'package:badminton/menu_bar.dart';
import 'package:badminton/page/auth/login_screen.dart';
import 'package:badminton/page/auth/otp_verification_screen.dart';
import 'package:badminton/page/auth/personal_info_screen.dart';
import 'package:badminton/page/auth/register_screen.dart';
import 'package:badminton/page/organizer/history/history_organizer.dart';
import 'package:badminton/page/organizer/history/history_organizer_payment.dart';
import 'package:badminton/page/organizer/manage/manage.dart';
import 'package:badminton/page/organizer/noti/organizer_noti_page.dart';
import 'package:badminton/page/user/noti/user_noti_page.dart';
import 'package:badminton/page/organizer/manage/manage_game.dart';
import 'package:badminton/page/organizer/new_game/add_game.dart';
import 'package:badminton/page/organizer/new_game/new_game.dart';
import 'package:badminton/page/organizer/profile/change_password_organizer.dart';
import 'package:badminton/page/organizer/profile/edit_profile.dart';
import 'package:badminton/page/organizer/profile/edit_skill_levels.dart';
import 'package:badminton/page/organizer/profile/edit_transfer.dart';
import 'package:badminton/page/organizer/profile/finance.dart';
import 'package:badminton/page/organizer/profile/profile_organizer.dart';
import 'package:badminton/page/user/booking_confirm.dart';
import 'package:badminton/page/user/history/history_detail.dart';
import 'package:badminton/page/user/history/history_user.dart';
import 'package:badminton/page/user/home_user.dart';
import 'package:badminton/page/user/my_game/game_player.dart';
import 'package:badminton/page/user/my_game/mygame_user.dart';
import 'package:badminton/page/user/otp.dart';
import 'package:badminton/page/user/payment/payment.dart';
import 'package:badminton/page/user/payment/payment_cancel.dart';
import 'package:badminton/page/user/payment/payment_history.dart';
import 'package:badminton/page/user/payment/payment_now.dart';
import 'package:badminton/page/user/player_list.dart';
import 'package:badminton/page/user/profile/apply_organizer.dart';
import 'package:badminton/page/user/profile/change_password.dart';
import 'package:badminton/page/user/profile/edit_profile.dart';
import 'package:badminton/page/user/profile/favourite.dart';
import 'package:badminton/page/user/profile/saved_payment.dart';
import 'package:badminton/page/user/profile/profile_user.dart';
import 'package:badminton/page/user/wallet/my_wallet_page.dart';
import 'package:badminton/page/user/search/search_user.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/user_role.dart';
import 'package:badminton/navigator_key.dart'; // --- FIX: Import navigator_key เพื่อใช้ Global Key ตัวเดียวกับ ApiProvider ---
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:badminton/shared/firebase_messaging_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:badminton/component/notification_provider.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

Future<void> main() async {
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  HttpOverrides.global = MyHttpOverrides();
  // runApp(MyApp());
  // runApp(
  //   // 1. ทำให้ UserRoleProvider สามารถเข้าถึงได้จากทุกที่ในแอป
  //   ChangeNotifierProvider(
  //     create: (context) => UserRoleProvider(),
  //     child: MyApp(),
  //   ),
  // );

  // NEW: ต้องมีบรรทัดนี้เสมอเมื่อใช้ async ใน main
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('th_TH', null);
  await Firebase.initializeApp(); // Initialize Firebase
  await FirebaseMessagingService().init(); // Initialize FCM Service
  // สร้าง provider และเรียก tryAutoLogin ก่อนรันแอป
  final authProvider = AuthProvider();
  await authProvider.tryAutoLogin();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UserRoleProvider()),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (context) => NotificationProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // MyApp({super.key});
  // final navigatorKey = GlobalKey<NavigatorState>(); // --- FIX: ลบบรรทัดนี้ทิ้ง เพื่อไม่ให้สร้าง Key ใหม่ทับตัว Global ---

  // เพิ่ม GlobalKey สำหรับ ShellRoute โดยเฉพาะ
  final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

        _setupInteractedMessage(); // ดักจับ Noti เมื่อเปิดแอป

    _router = GoRouter(
      refreshListenable: authProvider,
      navigatorKey: navigatorKey, // <-- เพิ่มบรรทัดนี้
      initialLocation: '/',
      redirect: (BuildContext context, GoRouterState state) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final bool loggedIn = authProvider.isLoggedIn;
        final String location = state.matchedLocation;

        // 1. หน้าสำหรับผู้ที่ยังไม่ได้ Login เท่านั้น (เช่น หน้าสมัคร/เข้าสู่ระบบ)
        final isAuthPage = location == '/login' || location == '/register-screen' || location == '/otp-verification-screen' || location == '/personal-info-screen';
        
        // 2. หน้าที่อนุญาตให้บุคคลทั่วไป (ยังไม่ Login) เข้าดูได้ (เพื่อผ่านกฎ Apple Guideline)
        final isPublicPage = location == '/' || location == '/search-user' || location.startsWith('/game-player/');

        if (!loggedIn && !isPublicPage && !isAuthPage) {
          authProvider.redirectAfterLogin = location;
          return '/login';
        }

        if (loggedIn && isAuthPage) {
          final target = authProvider.redirectAfterLogin;
          authProvider.redirectAfterLogin = null;
          return target ?? '/';
        }

        return null;
      },
      routes: [
        //regsiter
        GoRoute(
          path: '/register-screen',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/otp-verification-screen',
          // builder: (context, state) => const OtpVerificationScreen(phoneNumber: '',),
          builder: (context, state) {
            String? phoneNumber;
            dynamic tokens;

            if (state.extra is Map) {
              final map = state.extra as Map;
              phoneNumber = map['phoneNumber'];
              tokens = map['tokens'];
            } else if (state.extra is String) {
              phoneNumber = state.extra as String;
            }

            if (phoneNumber == null) {
              return const Scaffold(
                body: Center(child: Text('Error: ไม่พบข้อมูลเบอร์โทรศัพท์')),
              );
            }
            return OtpVerificationScreen(
              phoneNumber: phoneNumber,
              tokens: tokens,
            );
          },
        ),
        GoRoute(
          path: '/personal-info-screen',
          builder: (context, state) => const PersonalInfoScreen(),
        ),

        // ========================================================
        // --- เส้นทางที่ต้องการให้ซ่อนแถบเมนูด้านล่าง (Full Screen) ---
        // ========================================================
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/player-list/:id',
          builder: (context, state) {
            final String teamId = state.pathParameters['id']!;
            return PlayerListPage(id: teamId);
          },
        ),
        GoRoute(
          path: '/booking-confirm',
          builder: (context, state) {
            final details = state.extra as BookingDetails;
            return BookingConfirmPage(details: details);
          },
        ),
        GoRoute(
          path: '/game-player/:id',
          builder: (context, state) {
            final String bookingId = state.pathParameters['id']!;
            return GamePlayerPage(id: bookingId);
          },
        ),
        GoRoute(
          path: '/payment/:id',
          builder: (context, state) {
            final String bookingId = state.pathParameters['id']!;
            return PaymentPage(bookingId: bookingId);
          },
        ),
        GoRoute(
          path: '/booking-confirm-game',
          builder: (context, state) {
            final details = state.extra as BookingDetails;
            return BookingConfirmPage(details: details);
          },
        ),
        GoRoute(
          path: '/payment-cancel/:id',
          builder: (context, state) {
            final String bookingId = state.pathParameters['id']!;
            return PaymentCancelPage(code: bookingId);
          },
        ),
        GoRoute(
          path: '/payment-now/:id',
          builder: (context, state) {
            final String bookingId = state.pathParameters['id']!;
            return PaymentNowPage(code: bookingId);
          },
        ),
        GoRoute(
          path: '/payment-history/:id',
          builder: (context, state) {
            final String bookingId = state.pathParameters['id']!;
            return PaymentHistoryPage(code: bookingId);
          },
        ),
        GoRoute(
          path: '/history-detail/:id',
          builder: (context, state) {
            final String bookingId = state.pathParameters['id']!;
            return HistoryDetailPage(code: bookingId);
          },
        ),
        GoRoute(
          path: '/booking-confirm-history',
          builder: (context, state) {
            final details = state.extra as BookingDetails;
            return BookingConfirmPage(details: details);
          },
        ),
        GoRoute(
          path: '/edit-profile-user',
          builder: (context, state) => const EditProFileUserPage(),
        ),
        GoRoute(
          path: '/change-password',
          builder: (context, state) => const ChangePasswordPage(),
        ),
        GoRoute(
          path: '/saved-payment',
          builder: (context, state) => const SavedPaymentPage(),
        ),
        GoRoute(
          path: '/favourite',
          builder: (context, state) => const FavouritePage(),
        ),
        GoRoute(
          path: '/apply-organizer',
          builder: (context, state) => const ApplyOrganizerPage(),
        ),
        GoRoute(
          path: '/otp',
          builder: (context, state) {
            final phoneNumber = state.extra as String?;
            if (phoneNumber == null) {
              return const Scaffold(
                body: Center(child: Text('Error: ไม่พบข้อมูลเบอร์โทรศัพท์')),
              );
            }
            return OTPPage(phoneNumber: phoneNumber);
          },
        ),
        GoRoute(
          path: '/manage-game/:id',
          builder: (context, state) {
            final String teamId = state.pathParameters['id']!;
            return ManageGamePage(id: teamId);
          },
        ),
        GoRoute(
          path: '/history-organizer-payment',
          builder: (context, state) {
            final sessionId = state.extra as int? ?? 0;
            return HistoryOrganizerPaymentPage(sessionId: sessionId);
          },
        ),
        GoRoute(
          path: '/edit-profile-organizer',
          builder: (context, state) => EditProFileOrganizerPage(),
        ),
        GoRoute(
          path: '/edit-transfer',
          builder: (context, state) => EditTransferPage(),
        ),
        GoRoute(
          path: '/edit-skill-level',
          builder: (context, state) => EditSkillLevelsPage(),
        ),
        GoRoute(
          path: '/change-password-organizer',
          builder: (context, state) => const ChangePasswordOrganizerPage(),
        ),
        GoRoute(
          path: '/finance',
          builder: (context, state) => const FinancePage(),
        ),
        GoRoute(
          path: '/my-wallet',
          builder: (context, state) => const MyWalletPage(),
        ),
        GoRoute(
          path: '/organizer/noti',
          builder: (context, state) => const OrganizerNotificationPage(),
        ),
        GoRoute(
          path: '/user/noti',
          builder: (context, state) => const UserNotificationPage(),
        ),

        // ========================================================
        // --- เมนูหลักของแอป (มีแถบ MenuBar ด้านล่างเสมอ) -----------
        // ========================================================
        ShellRoute(
          navigatorKey: _shellNavigatorKey, // กำหนด Key ให้ ShellRoute
          builder: (context, state, child) {
            return MenuBarPage(child: child);
          },
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomePage(),
            ),
            GoRoute(
              path: '/new-game',
              builder: (context, state) => const NewGamePage(),
            ),
            GoRoute(
              path: '/add-game/:id',
              builder: (context, state) {
                final String bookingId = state.pathParameters['id']!;
                return AddGamePage(code: bookingId, extra: state.extra);
              },
            ),
            GoRoute(
              path: '/search-user',
              builder: (context, state) {
                final organizerId = state.uri.queryParameters['organizerId'];
                return SearchUserPage(organizerId: organizerId);
              },
            ),
            GoRoute(
              path: '/my-game-user',
              builder: (context, state) => const MyGameUserPage(),
            ),
            GoRoute(
              path: '/history-user',
              builder: (context, state) => const HistoryUserPage(),
            ),
            GoRoute(
              path: '/profile-user',
              builder: (context, state) => const ProFileUserPage(),
            ),
            GoRoute(
              path: '/manage',
              builder: (context, state) => const ManagePage(),
            ),
            GoRoute(
              path: '/history-organizer',
              builder: (context, state) => const HistoryOrganizerPage(),
            ),
            GoRoute(
              path: '/profile-organizer',
              builder: (context, state) => const ProFileOrganizerPage(),
            ),
          ],
        ),
      ],
    );
  }

  // --- NEW: จัดการการกด Noti เมื่อแอปปิดสนิท (Terminated State) ---
  Future<void> _setupInteractedMessage() async {
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      final referenceId = initialMessage.data['referenceId'];
      if (referenceId != null && referenceId.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final context = navigatorKey.currentContext;
          if (context != null) {
            final role = Provider.of<UserRoleProvider>(context, listen: false).currentRole;
            
            try {
              // ยิง API เช็คสถานะก่อน เพื่อไม่ให้เด้งไปหน้า Live Board มั่วๆ
              if (role == Role.organizer) {
                final response = await ApiProvider().get('/GameSessions/$referenceId');
                if (response['status'] == 200 && response['data'] != null) {
                  final int status = response['data']['status'] ?? 1;
                  if (status == 1) context.go('/manage');
                  else if (status == 2) context.push('/manage-game/$referenceId');
                  else context.push('/history-organizer-payment', extra: int.parse(referenceId));
                }
              } else {
                final response = await ApiProvider().get('/player/gamesessions/$referenceId');
                if (response['status'] == 200 && response['data'] != null) {
                  final int status = response['data']['status'] ?? 1;
                  final String userStatus = response['data']['currentUserStatus'] ?? 'NotJoined';
                  
                  if (status == 2 && userStatus == 'CheckedIn') {
                    context.push('/game-player/$referenceId');
                  } else if (status == 3 || status == 4 || userStatus == 'CheckedOut') {
                    context.push('/history-detail/$referenceId');
                  } else {
                    context.go('/my-game-user');
                  }
                }
              }
            } catch (e) {
              // ถ้าเช็ค API พัง ให้ปลอดภัยไว้ก่อนโดยกลับไปหน้าแรก
              if (context.mounted) {
                context.go('/');
              }
            }
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserRoleProvider>(
      builder: (context, userRoleProvider, child) {
        // เมื่อ Role เปลี่ยน, theme จะถูกสลับโดยอัตโนมัติ
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          // navigatorKey: navigatorKey,
          theme: userRoleProvider.currentTheme,
          title: "Badmintion",
          // home: MenuBarPage(),
          routerConfig: _router,
          // builder: (context, child) {
          //   return MediaQuery(
          //     data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
          //     child: child ?? Container(),
          //   );
          // },
        );
      },
    );
  }
}
