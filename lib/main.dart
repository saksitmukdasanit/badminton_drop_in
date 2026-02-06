import 'dart:io';

import 'package:badminton/menu_bar.dart';
import 'package:badminton/page/auth/login_screen.dart';
import 'package:badminton/page/auth/otp_verification_screen.dart';
import 'package:badminton/page/auth/personal_info_screen.dart';
import 'package:badminton/page/auth/register_screen.dart';
import 'package:badminton/page/organizer/history/history_organizer.dart';
import 'package:badminton/page/organizer/history/history_organizer_payment.dart';
import 'package:badminton/page/organizer/manage/manage.dart';
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
import 'package:badminton/page/user/mygame_user.dart';
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
import 'package:badminton/page/user/search_user.dart';
import 'package:badminton/shared/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

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
  // สร้าง provider และเรียก tryAutoLogin ก่อนรันแอป
  final authProvider = AuthProvider();
  await authProvider.tryAutoLogin();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UserRoleProvider()),
        ChangeNotifierProvider.value(value: authProvider),
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
  final navigatorKey = GlobalKey<NavigatorState>();

  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    _router = GoRouter(
      refreshListenable: authProvider,
      navigatorKey: navigatorKey, // <-- เพิ่มบรรทัดนี้
      initialLocation: '/',
      redirect: (BuildContext context, GoRouterState state) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final bool loggedIn = authProvider.isLoggedIn;
        final String location = state.matchedLocation;

        final isAuthPage =
            location == '/' ||
            location == '/login' ||
            location == '/register-screen' ||
            location == '/otp-verification-screen' ||
            location == '/personal-info-screen';
        final isPublicPage =
            location == '/search-user' ||
            location == '/my-game-user' ||
            location == '/history-user';

        if (!loggedIn && !isPublicPage && !isAuthPage) {
          authProvider.redirectAfterLogin = location;
          return '/login';
        }

        if (loggedIn && location == '/login') {
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
            final phoneNumber = state.extra as String?;
            if (phoneNumber == null) {
              return const Scaffold(
                body: Center(child: Text('Error: ไม่พบข้อมูลเบอร์โทรศัพท์')),
              );
            }
            return OtpVerificationScreen(phoneNumber: phoneNumber);
          },
        ),
        GoRoute(
          path: '/personal-info-screen',
          builder: (context, state) => const PersonalInfoScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) {
            return MenuBarPage(child: child);
          },
          routes: [
            //login
            GoRoute(
              path: '/login',
              builder: (context, state) => const LoginScreen(),
            ),
            //screen
            GoRoute(
              path: '/',
              builder: (context, state) => const HomeUserPage(),
            ),
            //หาก๊วน
            GoRoute(
              path: '/search-user',
              builder: (context, state) => const SearchUserPage(),
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
                // ดึงค่า extra ที่ส่งมา และ cast type ให้ถูกต้อง
                final details = state.extra as BookingDetails;

                // ส่ง object ที่ได้ไปให้หน้า BookingConfirmPage
                return BookingConfirmPage(details: details);
              },
            ),
            GoRoute(
              path: '/payment/:id',
              builder: (context, state) {
                final String bookingId = state.pathParameters['id']!;
                return PaymentPage(bookingId: bookingId);
              },
            ),

            // --- เกมของฉัน ---
            GoRoute(
              path: '/my-game-user',
              builder: (context, state) => const MyGameUserPage(),
            ),
            GoRoute(
              path: '/booking-confirm-game',
              builder: (context, state) {
                // ดึงค่า extra ที่ส่งมา และ cast type ให้ถูกต้อง
                final details = state.extra as BookingDetails;

                // ส่ง object ที่ได้ไปให้หน้า BookingConfirmPage
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

            // ---ประวัติ---
            GoRoute(
              path: '/history-user',
              builder: (context, state) => const HistoryUserPage(),
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
                // ดึงค่า extra ที่ส่งมา และ cast type ให้ถูกต้อง
                final details = state.extra as BookingDetails;

                // ส่ง object ที่ได้ไปให้หน้า BookingConfirmPage
                return BookingConfirmPage(details: details);
              },
            ),

            //โปรโฟล์
            GoRoute(
              path: '/profile-user',
              builder: (context, state) => const ProFileUserPage(),
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
              path: '/otp', //builder: (context, state) => const OTPPage()
              builder: (context, state) {
                final phoneNumber = state.extra as String?;
                if (phoneNumber == null) {
                  return const Scaffold(
                    body: Center(
                      child: Text('Error: ไม่พบข้อมูลเบอร์โทรศัพท์'),
                    ),
                  );
                }
                return OTPPage(phoneNumber: phoneNumber);
              },
            ),

            //---- ผู้จัด -----
            //------- New Game ----------
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
            //---- Manage ---
            GoRoute(
              path: '/manage',
              builder: (context, state) => const ManagePage(),
            ),
            GoRoute(
              path: '/manage-game/:id',
              builder: (context, state) {
                final String teamId = state.pathParameters['id']!;
                return ManageGamePage(id: teamId);
              },
            ),
            //---- ประวัติ ---
            GoRoute(
              path: '/history-organizer',
              builder: (context, state) => const HistoryOrganizerPage(),
            ),
            GoRoute(
              path: '/history-organizer-payment',
              builder: (context, state) => const HistoryOrganizerPaymentPage(),
            ),

            //---- โปรโฟล์---
            GoRoute(
              path: '/profile-organizer',
              builder: (context, state) => const ProFileOrganizerPage(),
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
          ],
        ),
      ],
    );
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
